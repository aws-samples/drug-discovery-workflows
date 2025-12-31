# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import logging
import cfnresponse
import boto3
from time import sleep

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


def delete_workflow_versions(workflow_id, omics_client):
    """Delete all versions of a workflow before deleting the workflow itself."""
    try:
        LOGGER.info(f"Checking for versions of workflow: {workflow_id}")
        paginator = omics_client.get_paginator("list_workflow_versions")
        version_count = 0
        
        for page in paginator.paginate(workflowId=workflow_id):
            for version in page.get("items", []):
                version_name = version["versionName"]
                LOGGER.info(f"Deleting workflow version: {workflow_id}/{version_name}")
                omics_client.delete_workflow_version(
                    workflowId=workflow_id,
                    versionName=version_name
                )
                version_count += 1
        
        if version_count > 0:
            LOGGER.info(f"Deleted {version_count} version(s) for workflow {workflow_id}")
        else:
            LOGGER.info(f"No versions found for workflow {workflow_id}")
            
    except Exception as e:
        LOGGER.warning(f"Error deleting versions for workflow {workflow_id}: {e}")
        # Continue anyway - the workflow might not have versions


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
            sleep(30)
            omics = boto3.client("omics")
            workflow_list = list_workflows_with_tags(
                tags={"StackPrefix": event["ResourceProperties"]["StackPrefix"]},
                omics_client=omics,
            )

            for workflow in workflow_list:
                # First delete all versions of the workflow
                delete_workflow_versions(workflow, omics)
                
                # Then delete the workflow itself
                LOGGER.info(f"Deleting workflow: {workflow}")
                response = omics.delete_workflow(id=workflow)
                LOGGER.info(f"Workflow deletion response:\n{response}")
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
