require("dotenv").config();
const express = require("express");
const bodyParser = require("body-parser");
const axios = require("axios");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const cors = require("cors");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

// Initialize Firebase Admin SDK
admin.initializeApp();

// Create an Express app
const app = express();

app.use(bodyParser.json());
app.use(cors({origin: true}));

// Define the secrets
const gmailEmailSecret = defineSecret("GMAIL_EMAIL");
const gmailPasswordSecret = defineSecret("GMAIL_PASSWORD");

let emailTransporter;

app.post("/sendCustomEmail", async (req, res) => {
  const {to, subject, body, attachmentUrl} = req.body;

  if (!to || !subject || !body) {
    return res.status(400).send({
      error: "Missing required fields: to, subject, body",
    });
  }

  try {
    if (!emailTransporter) {
      // Get the actual values from the secrets
      const email = gmailEmailSecret.value();
      const password = gmailPasswordSecret.value();

      if (!email || !password) {
        console.error("Gmail credentials not set in secrets.");
        return res.status(500).send({
          error: "Email service not configured.",
        });
      }

      emailTransporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: email,
          pass: password,
        },
      });
    }

    const emailAttachments = [];

    if (attachmentUrl) {
      console.log(`Downloading attachment from: ${attachmentUrl}`);
      try {
        const response = await axios.get(attachmentUrl, {
          responseType: "arraybuffer",
        });
        const buffer = Buffer.from(response.data, "binary");

        emailAttachments.push({
          filename: "Report.pdf",
          content: buffer,
          contentType: "application/pdf",
        });
      } catch (error) {
        console.error("Failed to download attachment:", error);
        return res.status(500).send({
          error: "Failed to download attachment.",
        });
      }
    }

    const mailOptions = {
      from: `"Memberssistant" <${gmailEmailSecret.value()}>`,
      to: to,
      subject: subject,
      html: `<p>${body.replace(/\n/g, "<br>")}</p>`,
      attachments: emailAttachments,
    };

    await emailTransporter.sendMail(mailOptions);
    console.log(`Email successfully sent to ${to}`);
    return res.status(200).send({success: true});
  } catch (error) {
    console.error("Error sending email:", error);
    return res.status(500).send({error: "Failed to send email."});
  }
});

// =========================================================================
// 6. EXPORT THE 'api' FUNCTION
// =========================================================================
exports.api = onRequest({
  timeoutSeconds: 120,
  memory: "1GiB",
  secrets: [gmailEmailSecret, gmailPasswordSecret],
}, app);
