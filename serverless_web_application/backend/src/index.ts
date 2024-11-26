// backend/src/index.ts
import { APIGatewayProxyHandlerV2 } from "aws-lambda";
import * as nodemailer from "nodemailer";

// SMTP（MailHog）の設定
const transporter = nodemailer.createTransport({
  host: "mailhog",
  port: 1025,
  secure: false,
});

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
  console.log("Received event:", JSON.stringify(event, null, 2));

  try {
    if (
      event.requestContext.http.method === "POST" &&
      event.requestContext.http.path === "/send-email"
    ) {
      const body = JSON.parse(event.body || "{}");

      // MailHogを使用してメール送信
      const info = await transporter.sendMail({
        from: "noreply@example.com",
        to: body.to,
        subject: body.subject,
        text: body.message,
      });

      console.log("Message sent: %s", info.messageId);

      return {
        statusCode: 200,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Headers": "Content-Type",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: "Email sent successfully",
          messageId: info.messageId,
        }),
      };
    }

    return {
      statusCode: 404,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message: "Not Found" }),
    };
  } catch (error) {
    console.error("Error:", error);
    return {
      statusCode: 500,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: "Internal Server Error",
        error: error.message,
      }),
    };
  }
};
