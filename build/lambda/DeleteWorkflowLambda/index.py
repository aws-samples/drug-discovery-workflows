# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import logging
import cfnresponse
import boto3

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def list_workflows_with_tags(tags, omics_client=boto3.client("omics")):

    LOGGER.info(f"Looking for workflows with the following tags:\n{tags}")

    output = []
    paginator = omics_client.get_paginator("list_workflows")
    for page in paginator.paginate():
        for workflow in page["items"]:
            workflow_tags = omics_client.list_tags_for_resource(
                resourceArn=workflow["arn"]
            ).get("tags")
            # is query_dict a subset of tags?
            if tags.items() <= workflow_tags.items():
                output.append(workflow["id"])
    LOGGER.info(f"Found the following workflows with matching tags:\n{output}")

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
            omics = boto3.client("omics")
            workflow_list = list_workflows_with_tags(
                tags={"StackPrefix": event["ResourceProperties"]["StackPrefix"]},
                omics_client=omics,
            )

            for workflow in workflow_list:
                LOGGER.info(f"Deleting workflow: {workflow}")
                response = omics.delete_workflow(id=workflow)
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
