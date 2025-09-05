const { generatePasswordResetEmail } = require('./src/utils/emailTemplates');

// Demo the email template
const demoEmail = () => {
  const resetToken = 'demo-reset-token-12345';
  const resetLink = `http://localhost:3000/reset-password?token=${resetToken}`;
  const emailContent = generatePasswordResetEmail('Sarah Johnson', resetLink);
  
  console.log('\n📧 PASSWORD RESET EMAIL DEMO');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`Subject: ${emailContent.subject}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('HTML Content Preview:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  
  // Show a simplified version of the HTML
  const simplifiedHTML = emailContent.html
    .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '') // Remove CSS
    .replace(/<[^>]+>/g, '') // Remove HTML tags
    .replace(/\s+/g, ' ') // Clean up whitespace
    .trim();
  
  console.log(simplifiedHTML);
  
  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('Text Content:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(emailContent.text);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`Reset Link: ${resetLink}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
};

demoEmail();
