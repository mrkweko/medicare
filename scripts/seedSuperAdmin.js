/**
 * One-off script to bootstrap the first super_admin account.
 *
 * Usage (emulator):
 *   FIRESTORE_EMULATOR_HOST=localhost:8070 \
 *   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
 *   GCLOUD_PROJECT=your-project-id \
 *   node seedSuperAdmin.js --email=super@example.com --password=changeme123
 *
 * Usage (production):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json \
 *   node seedSuperAdmin.js --email=super@example.com --password=changeme123
 *
 * Safe to re-run: if the auth user already exists, it reuses it and just
 * re-asserts the claims + Firestore doc rather than failing.
 */

const admin = require('firebase-admin');

function parseArgs() {
  const args = {};
  for (const arg of process.argv.slice(2)) {
    const match = arg.match(/^--([^=]+)=(.*)$/);
    if (match) args[match[1]] = match[2];
  }
  return args;
}

async function main() {
  const { email, password, displayName } = parseArgs();

  if (!email || !password) {
    console.error(
      'Usage: node seedSuperAdmin.js --email=<email> --password=<password> [--displayName=<name>]'
    );
    process.exit(1);
  }

  const usingEmulator = !!process.env.FIRESTORE_EMULATOR_HOST;

  if (usingEmulator) {
    admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-project' });
    console.log(`Running against EMULATOR (project: ${process.env.GCLOUD_PROJECT || 'demo-project'})`);
  } else {
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
    console.log('Running against PRODUCTION Firebase project — double check this is intended.');
  }

  const auth = admin.auth();
  const db = admin.firestore();

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`Found existing auth user: ${userRecord.uid}`);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    userRecord = await auth.createUser({
      email,
      password,
      displayName: displayName || 'Super Admin',
      emailVerified: true,
    });
    console.log(`Created new auth user: ${userRecord.uid}`);
  }

  await auth.setCustomUserClaims(userRecord.uid, {
    role: 'super_admin',
    hospitalId: null,
  });
  console.log('Custom claims set: { role: super_admin, hospitalId: null }');

  await db.collection('users').doc(userRecord.uid).set(
    {
      uid: userRecord.uid,
      email,
      displayName: displayName || 'Super Admin',
      role: 'super_admin',
      hospitalId: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`Firestore users/${userRecord.uid} doc written.`);

  console.log('\n✅ Super admin seeded successfully.');
  console.log(`   uid:   ${userRecord.uid}`);
  console.log(`   email: ${email}`);
  console.log(
    '\nNote: existing client sessions for this user must sign out/in (or force-refresh the ID token) before the new custom claims take effect.'
  );

  process.exit(0);
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});