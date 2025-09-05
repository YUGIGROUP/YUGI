const generatePasswordResetEmail = (userName, resetLink) => {
  const subject = "Reset Your YUGI Password";
  
  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Reset Your YUGI Password</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f8f9fa;
            }
            .container {
                background-color: #ffffff;
                border-radius: 12px;
                padding: 40px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            }
            .header {
                text-align: center;
                margin-bottom: 30px;
            }
            .logo {
                font-size: 32px;
                font-weight: bold;
                color: #BC6C5C;
                margin-bottom: 10px;
            }
            .greeting {
                font-size: 18px;
                margin-bottom: 20px;
                color: #333;
            }
            .content {
                margin-bottom: 30px;
                color: #666;
            }
            .reset-button {
                display: inline-block;
                background: linear-gradient(135deg, #BC6C5C, #BC6C5C);
                color: white;
                padding: 16px 32px;
                text-decoration: none;
                border-radius: 8px;
                font-weight: 600;
                font-size: 16px;
                margin: 20px 0;
                text-align: center;
                box-shadow: 0 2px 4px rgba(188, 108, 92, 0.3);
            }
            .security-note {
                background-color: #f8f9fa;
                border-left: 4px solid #BC6C5C;
                padding: 15px;
                margin: 20px 0;
                border-radius: 4px;
            }
            .footer {
                text-align: center;
                margin-top: 40px;
                padding-top: 20px;
                border-top: 1px solid #eee;
                color: #999;
                font-size: 14px;
            }
            .contact-info {
                margin-top: 15px;
                color: #666;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">YUGI</div>
                <h1 style="color: #333; margin: 0;">Reset Your Password</h1>
            </div>
            
            <div class="greeting">
                Hi ${userName || 'there'},
            </div>
            
            <div class="content">
                <p>We received a request to reset your YUGI account password. If you made this request, click the button below to create a new password.</p>
                
                <div style="text-align: center;">
                    <a href="${resetLink}" class="reset-button">Reset Password</a>
                </div>
                
                <div class="security-note">
                    <strong>Security Note:</strong> This link will expire in 1 hour for your security. If you don't reset your password within this time, you'll need to request a new reset link.
                </div>
                
                <p>If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.</p>
            </div>
            
            <div class="footer">
                <p>This email was sent from your YUGI account. If you have any questions, please contact us.</p>
                <div class="contact-info">
                    <p>Email: customer@yugi.uk</p>
                    <p>© 2024 YUGI. All rights reserved.</p>
                </div>
            </div>
        </div>
    </body>
    </html>
  `;
  
  const textContent = `
Reset Your YUGI Password

Hi ${userName || 'there'},

We received a request to reset your YUGI account password. If you made this request, click the link below to create a new password:

${resetLink}

Security Note: This link will expire in 1 hour for your security. If you don't reset your password within this time, you'll need to request a new reset link.

If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.

Contact us: customer@yugi.uk

© 2024 YUGI. All rights reserved.
  `;
  
  return {
    subject,
    html: htmlContent,
    text: textContent
  };
};

const generateWelcomeEmail = (userName) => {
  const subject = "Welcome to YUGI!";
  
  const htmlContent = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to YUGI</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f8f9fa;
            }
            .container {
                background-color: #ffffff;
                border-radius: 12px;
                padding: 40px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            }
            .header {
                text-align: center;
                margin-bottom: 30px;
            }
            .logo {
                font-size: 32px;
                font-weight: bold;
                color: #BC6C5C;
                margin-bottom: 10px;
            }
            .welcome-message {
                font-size: 24px;
                color: #333;
                margin-bottom: 20px;
            }
            .content {
                margin-bottom: 30px;
                color: #666;
            }
            .cta-button {
                display: inline-block;
                background: linear-gradient(135deg, #BC6C5C, #BC6C5C);
                color: white;
                padding: 16px 32px;
                text-decoration: none;
                border-radius: 8px;
                font-weight: 600;
                font-size: 16px;
                margin: 20px 0;
                text-align: center;
                box-shadow: 0 2px 4px rgba(188, 108, 92, 0.3);
            }
            .footer {
                text-align: center;
                margin-top: 40px;
                padding-top: 20px;
                border-top: 1px solid #eee;
                color: #999;
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <div class="logo">YUGI</div>
                <div class="welcome-message">Welcome to YUGI!</div>
            </div>
            
            <div class="content">
                <p>Hi ${userName},</p>
                
                <p>Welcome to YUGI! We're excited to have you join our community of parents and providers.</p>
                
                <p>With YUGI, you can:</p>
                <ul>
                    <li>Discover amazing classes for your children</li>
                    <li>Connect with trusted providers</li>
                    <li>Book classes easily and securely</li>
                    <li>Manage your family's activities in one place</li>
                </ul>
                
                <div style="text-align: center;">
                    <a href="${process.env.FRONTEND_URL}" class="cta-button">Start Exploring</a>
                </div>
                
                <p>If you have any questions or need help getting started, don't hesitate to reach out to our support team.</p>
            </div>
            
            <div class="footer">
                <p>Thank you for choosing YUGI!</p>
                <p>Email: customer@yugi.uk</p>
                <p>© 2024 YUGI. All rights reserved.</p>
            </div>
        </div>
    </body>
    </html>
  `;
  
  return {
    subject,
    html: htmlContent
  };
};

module.exports = {
  generatePasswordResetEmail,
  generateWelcomeEmail
};
