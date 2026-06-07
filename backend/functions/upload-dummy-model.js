const admin = require("firebase-admin");
const fs = require("fs");

// Point to storage emulator
process.env.FIREBASE_STORAGE_EMULATOR_HOST = "127.0.0.1:9199";

admin.initializeApp({
  projectId: "speakeasy-demo",
  storageBucket: "my-bucket"
});

async function upload() {
  const bucket = admin.storage().bucket();
  
  // Create a dummy file locally
  const tempFilePath = "./dummy-model.zip";
  fs.writeFileSync(tempFilePath, "This is dummy model content. It works!");
  
  // Upload to GCS emulator
  await bucket.upload(tempFilePath, {
    destination: "models/user_test.zip"
  });
  
  // Clean up local file
  fs.unlinkSync(tempFilePath);
  
  console.log("Successfully uploaded dummy-model.zip to local Storage emulator!");
}

upload().catch(console.error);
