const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();

/**
 * HTTP Cloud Function to handle authorized model download links.
 * Endpoint: GET /downloadModel
 * Headers: Authorization: Bearer <token>
 * Alternatively: GET /downloadModel?token=<token>
 */
exports.downloadModel = onRequest({ cors: true }, async (req, res) => {
  // Only allow GET requests
  if (req.method !== "GET") {
    res.status(405).json({ error: "Method Not Allowed" });
    return;
  }

  // Extract the paid token from Authorization header or query parameter
  let token = null;
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith("Bearer ")) {
    token = authHeader.substring(7).trim();
  } else if (req.query.token) {
    token = req.query.token.toString().trim();
  }

  if (!token) {
    res.status(401).json({ error: "Unauthorized. Missing paid_token." });
    return;
  }

  try {
    // Look up the token in the 'paid_tokens' collection.
    // We check both if the document ID matches the token, or if there is a 'paid_token' field matching it.
    let tokenDoc = await db.collection("paid_tokens").doc(token).get();
    
    // If not found by doc ID, attempt query by field
    if (!tokenDoc.exists) {
      const querySnapshot = await db.collection("paid_tokens")
        .where("paid_token", "==", token)
        .limit(1)
        .get();
      
      if (!querySnapshot.empty) {
        tokenDoc = querySnapshot.docs[0];
      }
    }

    if (!tokenDoc.exists) {
      res.status(403).json({ error: "Forbidden. Invalid paid_token." });
      return;
    }

    const tokenData = tokenDoc.data();

    // Verify token status
    if (tokenData.token_status !== "active") {
      res.status(403).json({ 
        error: `Forbidden. Token status is currently '${tokenData.token_status || "inactive"}'.` 
      });
      return;
    }

    const modelStoragePath = tokenData.model_storage_path;
    if (!modelStoragePath) {
      res.status(500).json({ error: "Internal Server Error. Model storage path not configured for this token." });
      return;
    }

    // Determine the bucket and file path from model_storage_path (e.g. "gs://my-bucket/models/user1.zip" or "models/user1.zip")
    let bucket;
    let filePath;

    if (modelStoragePath.startsWith("gs://")) {
      const cleanPath = modelStoragePath.replace("gs://", "");
      const slashIndex = cleanPath.indexOf("/");
      if (slashIndex === -1) {
        res.status(500).json({ error: "Internal Server Error. Invalid model storage path format." });
        return;
      }
      const bucketName = cleanPath.substring(0, slashIndex);
      filePath = cleanPath.substring(slashIndex + 1);
      bucket = admin.storage().bucket(bucketName);
    } else {
      // Use default storage bucket
      bucket = admin.storage().bucket();
      filePath = modelStoragePath;
    }

    const file = bucket.file(filePath);
    
    // Verify file exists before generating the URL
    const [exists] = await file.exists();
    if (!exists) {
      res.status(404).json({ 
        error: "Model file not found. The model might still be training or generating. Please try again later." 
      });
      return;
    }

    // Get file metadata to report file size
    const [metadata] = await file.getMetadata();
    const fileSize = parseInt(metadata.size, 10) || 0;

    // Handle local emulator vs production environments
    let downloadUrl;
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      // Local emulator: return the direct emulator GCS URL
      const storageHost = process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
      const encodedPath = encodeURIComponent(filePath);
      downloadUrl = `http://${storageHost}/v0/b/${bucket.name}/o/${encodedPath}?alt=media`;
    } else {
      // Production: Generate a secure, presigned URL valid for 5 minutes (300 seconds)
      const expiresMs = Date.now() + 5 * 60 * 1000;
      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: expiresMs,
      });
      downloadUrl = signedUrl;
    }

    // Extract filename for display purposes
    const filename = filePath.split("/").pop() || "model.zip";

    res.status(200).json({
      downloadUrl,
      modelName: tokenData.model_name || filename.replace(".zip", ""),
      fileSize,
      expiresIn: 300,
    });

  } catch (error) {
    console.error("Error generating presigned URL:", error);
    res.status(500).json({ error: "Internal Server Error. Failed to generate download URL." });
  }
});
