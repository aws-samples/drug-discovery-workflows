import logging
import cfnresponse
import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def lambda_handler(event, context):
    try:
        LOGGER.info("REQUEST RECEIVED:\n %s", event)
        LOGGER.info("REQUEST RECEIVED:\n %s", context)
        if event["RequestType"] == "Create":
            LOGGER.info("CREATE!")
            client = boto3.client("codebuild")
            project_name = event["ResourceProperties"]["ProjectName"]
            _ = client.start_build(projectName=project_name)
            cfnresponse.send(
                event,
                context,
                cfnresponse.SUCCESS,
                {"response": "Resource creation successful!"},
            )
        elif event["RequestType"] == "Update":
            LOGGER.info("UPDATE!")
            client = boto3.client("codebuild")
            project_name = event["ResourceProperties"]["ProjectName"]
            _ = client.start_build(projectName=project_name)
            cfnresponse.send(
                event,
                context,
                cfnresponse.SUCCESS,
                {"response": "Resource update successful!"},
            )
        elif event["RequestType"] == "Delete":
            LOGGER.info("DELETE!")
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
