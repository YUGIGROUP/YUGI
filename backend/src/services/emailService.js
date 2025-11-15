const { generatePasswordResetEmail, generateWelcomeEmail, generateBookingConfirmationEmail } = require('../utils/emailTemplates');

class EmailService {
  constructor() {
    this.isProduction = process.env.NODE_ENV === 'production';
    this.fromEmail = process.env.FROM_EMAIL || 'info@yugiapp.ai';
    this.fromName = 'YUGI';
  }

  async sendPasswordResetEmail(userEmail, userName, resetToken) {
    const resetLink = `${process.env.FRONTEND_URL}/reset-password?token=${resetToken}`;
    const emailContent = generatePasswordResetEmail(userName, resetLink);
    
    if (this.isProduction) {
      // In production, send actual email
      return await this.sendEmail(userEmail, emailContent.subject, emailContent.html, emailContent.text);
    } else {
      // In development, log the email content
      console.log('\n📧 PASSWORD RESET EMAIL SENT:');
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log(`To: ${userEmail}`);
      console.log(`Subject: ${emailContent.subject}`);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('HTML Content:');
      console.log(emailContent.html);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('Text Content:');
      console.log(emailContent.text);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log(`Reset Link: ${resetLink}`);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      return { success: true, message: 'Email logged to console (development mode)' };
    }
  }

  async sendWelcomeEmail(userEmail, userName) {
    const emailContent = generateWelcomeEmail(userName);
    
    if (this.isProduction) {
      // In production, send actual email
      return await this.sendEmail(userEmail, emailContent.subject, emailContent.html);
    } else {
      // In development, log the email content
      console.log('\n📧 WELCOME EMAIL SENT:');
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log(`To: ${userEmail}`);
      console.log(`Subject: ${emailContent.subject}`);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('HTML Content:');
      console.log(emailContent.html);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      return { success: true, message: 'Email logged to console (development mode)' };
    }
  }

  async sendBookingConfirmationEmail(userEmail, bookingDetails) {
    const emailContent = generateBookingConfirmationEmail(bookingDetails);
    
    if (this.isProduction) {
      // In production, send actual email
      return await this.sendEmail(userEmail, emailContent.subject, emailContent.html, emailContent.text);
    } else {
      // In development, log the email content
      console.log('\n📧 BOOKING CONFIRMATION EMAIL SENT:');
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log(`To: ${userEmail}`);
      console.log(`Subject: ${emailContent.subject}`);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('Booking Details:');
      console.log(`  Booking Number: ${bookingDetails.bookingNumber}`);
      console.log(`  Class: ${bookingDetails.className}`);
      console.log(`  Date: ${bookingDetails.sessionDate}`);
      console.log(`  Time: ${bookingDetails.sessionTime}`);
      console.log(`  Total: £${bookingDetails.totalAmount.toFixed(2)}`);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('HTML Content:');
      console.log(emailContent.html);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('Text Content:');
      console.log(emailContent.text);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      
      return { success: true, message: 'Email logged to console (development mode)' };
    }
  }

  async sendEmail(to, subject, html, text = null) {
    // This is where you would integrate with an email service provider
    // Examples: SendGrid, AWS SES, Mailgun, etc.
    
    if (process.env.EMAIL_PROVIDER === 'sendgrid') {
      return await this.sendWithSendGrid(to, subject, html, text);
    } else if (process.env.EMAIL_PROVIDER === 'ses') {
      return await this.sendWithSES(to, subject, html, text);
    } else if (process.env.EMAIL_PROVIDER === 'mailgun') {
      return await this.sendWithMailgun(to, subject, html, text);
    } else {
      // Default: log email (for development)
      console.log(`📧 Email would be sent to ${to}: ${subject}`);
      return { success: true, message: 'Email service not configured' };
    }
  }

  // Example SendGrid integration
  async sendWithSendGrid(to, subject, html, text) {
    // You would need to install: npm install @sendgrid/mail
    // const sgMail = require('@sendgrid/mail');
    // sgMail.setApiKey(process.env.SENDGRID_API_KEY);
    
    // const msg = {
    //   to: to,
    //   from: {
    //     email: this.fromEmail,
    //     name: this.fromName
    //   },
    //   subject: subject,
    //   html: html,
    //   text: text
    // };
    
    // return await sgMail.send(msg);
    
    console.log(`📧 SendGrid email would be sent to ${to}: ${subject}`);
    return { success: true, message: 'SendGrid not configured' };
  }

  // Example AWS SES integration
  async sendWithSES(to, subject, html, text) {
    // You would need to install: npm install aws-sdk
    // const AWS = require('aws-sdk');
    // const ses = new AWS.SES({
    //   region: process.env.AWS_REGION,
    //   accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    //   secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
    // });
    
    // const params = {
    //   Source: `${this.fromName} <${this.fromEmail}>`,
    //   Destination: { ToAddresses: [to] },
    //   Message: {
    //     Subject: { Data: subject },
    //     Body: {
    //       Html: { Data: html },
    //       Text: { Data: text || html.replace(/<[^>]*>/g, '') }
    //     }
    //   }
    // };
    
    // return await ses.sendEmail(params).promise();
    
    console.log(`📧 AWS SES email would be sent to ${to}: ${subject}`);
    return { success: true, message: 'AWS SES not configured' };
  }

  // Example Mailgun integration
  async sendWithMailgun(to, subject, html, text) {
    // You would need to install: npm install mailgun.js
    // const formData = require('form-data');
    // const Mailgun = require('mailgun.js');
    // const mailgun = new Mailgun(formData);
    // const client = mailgun.client({
    //   username: 'api',
    //   key: process.env.MAILGUN_API_KEY
    // });
    
    // const messageData = {
    //   from: `${this.fromName} <${this.fromEmail}>`,
    //   to: to,
    //   subject: subject,
    //   html: html,
    //   text: text
    // };
    
    // return await client.messages.create(process.env.MAILGUN_DOMAIN, messageData);
    
    console.log(`📧 Mailgun email would be sent to ${to}: ${subject}`);
    return { success: true, message: 'Mailgun not configured' };
  }
}

module.exports = new EmailService();
