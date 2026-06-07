const admin = require("firebase-admin");

// Configure the Admin SDK to point to our local Firestore Emulator port
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";

admin.initializeApp({
  projectId: "speakeasy-demo"
});

const db = admin.firestore();

async function seed() {
  const token = "tkn_test_999";
  const docRef = db.collection("paid_tokens").doc(token);
  
  await docRef.set({
    paid_token: token,
    token_status: "active",
    model_storage_path: "gs://my-bucket/models/user_test.zip",
    model_name: "Test-User-Whisper-v1"
  });
  
  console.log("Successfully seeded token 'tkn_test_999' into local Firestore emulator database!");
}

seed().catch(console.error);
