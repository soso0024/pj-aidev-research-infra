# infrastructure/ses.tf
resource "aws_ses_email_identity" "sender" {
  email = "noreply@example.com"
}
