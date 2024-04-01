import logging
import cfnresponse
import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def list_repositories_with_prefix(prefix=None, ecr_client=boto3.client("ecr")):
    """
    List all ECR repositories with a given prefix
    """
    LOGGER.info(f"Getting list of repositories with prefix: {prefix}")

    paginator = ecr_client.get_paginator("describe_repositories")
    repos = []
    for page in paginator.paginate():
        repos.extend(
            [
                repo["repositoryName"]
                for repo in page["repositories"]
                if repo["repositoryName"].startswith(prefix)
            ]
        )
    return repos


def lambda_handler(event, context):
    try:
        LOGGER.info("REQUEST RECEIVED:\n %s", event)
        LOGGER.info("REQUEST RECEIVED:\n %s", context)
        if event["RequestType"] == "Create":
            LOGGER.info("CREATE!")
            cfnresponse.send(
                event,
                context,
                cfnresponse.SUCCESS,
                {"response": "Resource creation successful!"},
            )
        elif event["RequestType"] == "Update":
            LOGGER.info("UPDATE!")
            cfnresponse.send(
                event,
                context,
                cfnresponse.SUCCESS,
                {"response": "Resource update successful!"},
            )
        elif event["RequestType"] == "Delete":
            LOGGER.info("DELETE!")
            ecr = boto3.client("ecr")
            repo_list = list_repositories_with_prefix(
                prefix=event["ResourceProperties"]["StackPrefix"],
                ecr_client=ecr,
            )

            for repo_name in repo_list:
                LOGGER.info(f"Deleting repo: {repo_name}")
                response = ecr.delete_repository(repositoryName=repo_name, force=True)
                LOGGER.info(f"Repo deletion response:\n{response}")
            cfnresponse.send(
                event,
                context,
                cfnresponse.SUCCESS,
                {"response": "Resource deletion successful!"},
            )
        else:
            LOGGER.info("FAILED!")
            cfnresponse.send(
                event,
                context,
                cfnresponse.FAILED,
                {"response": "Unexpected event received from CloudFormation"},
            )
    except:
        LOGGER.info("FAILED!")
        cfnresponse.send(
            event,
            context,
            cfnresponse.FAILED,
            {"response": "Exception during processing"},
        )
