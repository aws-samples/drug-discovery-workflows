import logging
import cfnresponse
import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def list_repositories_with_tags(tags, ecr_client=boto3.client("ecr")):
    output = []
    paginator = ecr_client.get_paginator("describe_repositories")
    for page in paginator.paginate():
        for repo in page["repositories"]:
            repo_tags = {
                record.get("Key"): record.get("Value")
                for record in ecr_client.list_tags_for_resource(
                    resourceArn=repo["repositoryArn"]
                ).get("tags")
            }
            # is query_dict a subset of tags?
            if tags.items() <= repo_tags.items():
                output.append(repo["repositoryName"])
    LOGGER.info(f"Found the following repositories with matching tags:\n{output}")

    return output


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
            repo_list = list_repositories_with_tags(
                tags={"StackPrefix": event["ResourceProperties"]["StackPrefix"]},
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
            LOGGER.error("FAILED!")
            cfnresponse.send(
                event,
                context,
                cfnresponse.FAILED,
                {"response": "Unexpected event received from CloudFormation"},
            )
    except Exception as e:
        LOGGER.error("FAILED!")
        LOGGER.error(e)
        cfnresponse.send(
            event,
            context,
            cfnresponse.FAILED,
            {"response": "Exception during processing"},
        )
