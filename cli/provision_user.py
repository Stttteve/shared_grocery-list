import boto3
import sys
import qrcode
import base64
import subprocess
import sys as _sys
from io import BytesIO
from botocore.exceptions import ClientError

# Initialize IAM client
iam = boto3.client('iam')


def create_user(username, group):
    """
    Create a new IAM user, attach to a group, enforce MFA, and output credentials.

    Args:
        username (str): IAM username to create.
        group    (str): IAM group name to add the user to (e.g., 'Shoppers' or 'Viewers').
    """
    # 1. Create user (skip if exists)
    try:
        iam.create_user(UserName=username)
        print(f"Created user {username}")
    except ClientError as e:
        if e.response['Error']['Code'] == 'EntityAlreadyExists':
            print(f"User '{username}' already exists, continuing...")
        else:
            raise

    # 2. Attach user to group
    try:
        iam.add_user_to_group(GroupName=group, UserName=username)
        print(f"Added user '{username}' to group '{group}'")
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchEntity':
            print(f"Group '{group}' does not exist.")
            sys.exit(1)
        else:
            raise

    # 3. Create access keys
    keys = iam.create_access_key(UserName=username)['AccessKey']
    print(f"Generated access keys for '{username}'")

    # 4. Create virtual MFA device
    mfa_response = iam.create_virtual_mfa_device(VirtualMFADeviceName=username)
    virtual_device = mfa_response['VirtualMFADevice']

    # 5. Decode QR code PNG from API and save locally
    png_bytes = virtual_device['QRCodePNG']
    qr_filename = f"{username}_mfa.png"
    with open(qr_filename, 'wb') as f:
        f.write(png_bytes)
    print(f"MFA QR code written to {qr_filename}")

    # 6. Optionally open the QR image
    try:
        if _sys.platform == 'darwin':
            subprocess.run(['open', qr_filename])
        elif _sys.platform.startswith('linux'):
            subprocess.run(['xdg-open', qr_filename])
    except Exception:
        pass

    # 7. Prompt user to scan and enter two consecutive TOTP codes
    code1 = input("Enter first MFA code: ")
    code2 = input("Enter second MFA code: ")

    # 8. Enable MFA device on the user
    iam.enable_mfa_device(
        UserName=username,
        SerialNumber=virtual_device['SerialNumber'],
        AuthenticationCode1=code1,
        AuthenticationCode2=code2
    )
    print(f"MFA enabled for user '{username}'")

    # 9. Output final credentials
    print("\n=== Credentials ===")
    print(f"Access Key ID: {keys['AccessKeyId']}")
    print(f"Secret Access Key: {keys['SecretAccessKey']}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python provision_user.py <username> <group>")
        sys.exit(1)

    create_user(sys.argv[1], sys.argv[2])