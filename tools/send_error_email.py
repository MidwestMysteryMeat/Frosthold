#!/usr/bin/env python3
"""Send FROSTHOLD crash report via Gmail SMTP.

Usage:
    python send_error_email.py <error_file> [screenshot_file]

Requires env vars:
    FROSTHOLD_EMAIL_PASSWORD  — Gmail App Password (16 chars, no spaces)

To generate an App Password:
    1. Go to https://myaccount.google.com/apppasswords
    2. Select "Mail" and your device
    3. Copy the 16-character password
    4. Set it:  set FROSTHOLD_EMAIL_PASSWORD=abcdefghijklmnop
"""

import smtplib
import sys
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
from datetime import datetime

SMTP_SERVER = 'smtp.gmail.com'
SMTP_PORT = 587
FROM_EMAIL = 'midwestmysterymeatstudios@gmail.com'
TO_EMAIL = 'midwestmysterymeatstudios@gmail.com'


def send_crash_report(error_file, screenshot_file=None):
    password = os.environ.get('FROSTHOLD_EMAIL_PASSWORD')
    if not password:
        print('[ERROR] FROSTHOLD_EMAIL_PASSWORD env var not set.')
        print('Generate a Gmail App Password at https://myaccount.google.com/apppasswords')
        sys.exit(1)

    # Read error text
    with open(error_file, 'r', encoding='utf-8') as f:
        error_text = f.read()

    # Build email
    msg = MIMEMultipart()
    msg['From'] = FROM_EMAIL
    msg['To'] = TO_EMAIL
    msg['Subject'] = f'FROSTHOLD CRASH — {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}'

    body = f'FROSTHOLD Crash Report\n{"="*40}\n\n{error_text}'
    msg.attach(MIMEText(body, 'plain'))

    # Attach screenshot if available
    if screenshot_file and os.path.isfile(screenshot_file):
        with open(screenshot_file, 'rb') as f:
            part = MIMEBase('image', 'png')
            part.set_payload(f.read())
            encoders.encode_base64(part)
            part.add_header(
                'Content-Disposition',
                f'attachment; filename="crash_screenshot.png"'
            )
            msg.attach(part)

    # Send
    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.starttls()
        server.login(FROM_EMAIL, password)
        server.send_message(msg)
        server.quit()
        print('[OK] Crash report emailed to', TO_EMAIL)
    except smtplib.SMTPAuthenticationError:
        print('[ERROR] Gmail auth failed. Make sure you are using an App Password,')
        print('        not your regular Gmail password.')
        print('        Generate one at https://myaccount.google.com/apppasswords')
        sys.exit(1)
    except Exception as e:
        print(f'[ERROR] Failed to send email: {e}')
        sys.exit(1)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f'Usage: {sys.argv[0]} <error_file> [screenshot_file]')
        sys.exit(1)

    error_file = sys.argv[1]
    screenshot_file = sys.argv[2] if len(sys.argv) > 2 else None
    send_crash_report(error_file, screenshot_file)
