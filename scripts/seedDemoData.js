/**
 * Seeds one demo hospital with departments, a hospital_admin, a few
 * doctors, a receptionist, and a couple of patients — everything needed
 * to demo the app without manually creating accounts each emulator reset.
 *
 * Usage (emulator only — this script intentionally refuses to run against
 * production, see the guard below):
 *   FIRESTORE_EMULATOR_HOST=localhost:8070 \
 *   FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
 *   GCLOUD_PROJECT=your-project-id \
 *   node seedDemoData.js
 */

const admin = require('firebase-admin');

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('Refusing to run: FIRESTORE_EMULATOR_HOST is not set. This script is for the emulator only.');
  process.exit(1);
}

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT || 'demo-project' });
const auth = admin.auth();
const db = admin.firestore();

async function createUser({ email, password, displayName, role, hospitalId, departmentId, avgConsultationMinutes }) {
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
  } catch {
    userRecord = await auth.createUser({ email, password, displayName, emailVerified: true });
  }
  await auth.setCustomUserClaims(userRecord.uid, { role, hospitalId: hospitalId ?? null });
  await db.collection('users').doc(userRecord.uid).set(
    {
      uid: userRecord.uid,
      email,
      displayName,
      phoneNumber: null,
      role,
      hospitalId: hospitalId ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  if (role === 'doctor') {
    await db.collection('doctors').doc(userRecord.uid).set(
      {
        uid: userRecord.uid,
        displayName,
        hospitalId,
        departmentId,
        avgConsultationMinutes: avgConsultationMinutes ?? 15,
        recentConsultationDurations: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  }
  return userRecord.uid;
}

async function main() {
  console.log('Seeding demo hospital...');

  const hospitalRef = db.collection('hospitals').doc('demo-hospital');
  await hospitalRef.set(
    {
      name: 'Demo General Hospital',
      address: '123 Example Road, Kampala',
      contactInfo: '+256700000000',
      skipPolicy: 'end_of_queue',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  const hospitalId = hospitalRef.id;

  const departments = [
    { id: 'demo-dept-general', name: 'General Medicine' },
    { id: 'demo-dept-pediatrics', name: 'Pediatrics' },
    { id: 'demo-dept-lab', name: 'Lab' },
  ];
  for (const dept of departments) {
    await db.collection('departments').doc(dept.id).set(
      { hospitalId, name: dept.name, createdAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true }
    );
  }

  const hospitalAdminUid = await createUser({
    email: 'admin@demo-hospital.test',
    password: 'password123',
    displayName: 'Demo Hospital Admin',
    role: 'hospital_admin',
    hospitalId,
  });

  const receptionistUid = await createUser({
    email: 'reception@demo-hospital.test',
    password: 'password123',
    displayName: 'Demo Receptionist',
    role: 'receptionist',
    hospitalId,
  });

  const doctorConfigs = [
    { email: 'dr.general@demo-hospital.test', name: 'Dr. Amina General', dept: 'demo-dept-general', avg: 12 },
    { email: 'dr.peds@demo-hospital.test', name: 'Dr. Kofi Pediatrics', dept: 'demo-dept-pediatrics', avg: 20 },
  ];
  for (const dc of doctorConfigs) {
    await createUser({
      email: dc.email,
      password: 'password123',
      displayName: dc.name,
      role: 'doctor',
      hospitalId,
      departmentId: dc.dept,
      avgConsultationMinutes: dc.avg,
    });
  }

  const patientConfigs = [
    { email: 'patient1@demo.test', name: 'Demo Patient One' },
    { email: 'patient2@demo.test', name: 'Demo Patient Two' },
  ];
  for (const pc of patientConfigs) {
    await createUser({ email: pc.email, password: 'password123', displayName: pc.name, role: 'patient' });
  }

  console.log('\n✅ Demo data seeded.');
  console.log(`   Hospital: ${hospitalId}`);
  console.log('   Login (all passwords: password123):');
  console.log('     hospital_admin: admin@demo-hospital.test');
  console.log('     receptionist:   reception@demo-hospital.test');
  console.log('     doctors:        dr.general@demo-hospital.test, dr.peds@demo-hospital.test');
  console.log('     patients:       patient1@demo.test, patient2@demo.test');

  process.exit(0);
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});