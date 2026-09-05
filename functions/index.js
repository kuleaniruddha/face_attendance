const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// 🔐 EMAIL CONFIG (GMAIL)
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: functions.config().gmail.user,
    pass: functions.config().gmail.pass,
  },
});


// 🔔 TRIGGER ON APPROVAL
exports.notifyUserOnApproval = functions.firestore
  .document("signup_requests/{requestId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only trigger when status changes to approved
    if (before.status === "pending" && after.status === "approved") {
      const email = after.email;
      const fullName = after.fullName;

      const mailOptions = {
        from: "ONGC Face Attendance <aniruddhakule@gmail.com>",
        to: email,
        subject: "Your Access Has Been Approved",
        html: `
          <h2>Hello ${fullName},</h2>
          <p>Your access request has been <b>approved</b>.</p>
          <p><b>Login Details:</b></p>
          <ul>
            <li>Email: ${email}</li>
            <li>Password: <b>123456</b></li>
          </ul>
          <p>Please login and change your password immediately.</p>
          <br>
          <p>— ONGC Attendance System</p>
        `,
      };

      await transporter.sendMail(mailOptions);
      console.log("Approval email sent to", email);
    }
  });
