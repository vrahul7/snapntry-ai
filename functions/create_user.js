/**
 * Script to create/update a Firebase Auth user using Admin SDK
 * Run: node create_user.js
 */
const admin = require('firebase-admin');

// Initialize the app with project ID (uses Application Default Credentials)
admin.initializeApp({
  projectId: 'b2b-gena2z-prod-8898'
});

const auth = admin.auth();

const email = 'vgrahul7@gmail.com';
const password = '12345679';

async function createOrUpdateUser() {
  try {
    // Try to get the user first
    let user;
    try {
      user = await auth.getUserByEmail(email);
      console.log(`User already exists: ${user.uid}. Updating password...`);
      user = await auth.updateUser(user.uid, {
        password: password,
        displayName: 'Rahul G',
        emailVerified: true,
        disabled: false
      });
      console.log(`✅ User updated successfully: ${user.uid}`);
    } catch (err) {
      if (err.code === 'auth/user-not-found') {
        console.log('User not found. Creating new user...');
        user = await auth.createUser({
          email: email,
          password: password,
          displayName: 'Rahul G',
          emailVerified: true,
          disabled: false
        });
        console.log(`✅ User created successfully: ${user.uid}`);
      } else {
        throw err;
      }
    }
    
    console.log(`\n📧 Email: ${email}`);
    console.log(`🔑 Password: ${password}`);
    console.log(`🆔 UID: ${user.uid}`);
    console.log('\nUser is ready to use the app!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error creating/updating user:', error.message);
    process.exit(1);
  }
}

createOrUpdateUser();
