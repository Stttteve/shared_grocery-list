import boto3


def lambda_handler(event, context):
    iam = boto3.client('iam')
    username = event['username']

    groups = iam.list_groups_for_user(UserName=username)
    group_names = [g['GroupName'] for g in groups['Groups']]

    return {
        'is_shopper': 'Shoppers' in group_names,
        'is_viewer': 'Viewers' in group_names
    }