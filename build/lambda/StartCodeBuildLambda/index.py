# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import logging
import cfnresponse
import boto3
import os
from io import BytesIO
import zipfile

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)


def download_obj_from_s3(uri: str) -> BytesIO:
    """
    Download an object from Amazon S3.
    :param uri: The URI of the object to download.
    :return: The object data.
    """
    LOGGER.info(f"Downloading {uri}")
    bucket, key = uri.replace("s3://", "").split("/", 1)
    s3 = boto3.resource("s3")
    obj = s3.Object(bucket, key)
    data = obj.get()["Body"].read()
    return BytesIO(data)


def get_zipfile_subfolders(zipdata: BytesIO, subfolder: str) -> list:
    """
    Count the number of subfolders in a zip file.
    :param zipdata: The zip file data.
    :param at: The path to start counting from.
    :return: List of the subfolders
    """

    subfolder = os.path.join(subfolder, "")

    return [
        path.name for path in zipfile.Path(zipdata, subfolder).iterdir() if path.is_dir and not path.name.startswith('.')
    ]


def start_artifact_build(
    source_s3: str,
    source_subfolder: str,
    project_name: str,
) -> int:
    """
    Start a CodeBuild run for each artifact in the source zip file.
    :param source_s3: The URI of the source zip file.
    :param source_subfolder: The path to the source zip file.
    :param project_name: The CodeBuild project name.
    :return: The number of artifacts started.
    """

    codebuild_client = boto3.client("codebuild")
    source_zip = download_obj_from_s3(source_s3)
    artifacts = get_zipfile_subfolders(source_zip, source_subfolder)
    for artifact in artifacts:
        LOGGER.info(f"Starting CodeBuild run for {artifact}")
        response = codebuild_client.start_build(
            projectName=project_name,
            environmentVariablesOverride=[
                {
                    "name": "NAME",
                    "value": artifact,
                    "type": "PLAINTEXT",
                },
                {
                    "name": "BUILD_CONTEXT",
                    "value": os.path.join(source_subfolder, artifact),
                    "type": "PLAINTEXT",
                },
            ],
        )
        LOGGER.info(response)
    return len(artifacts)


def lambda_handler(event, context):
    try:
        LOGGER.info("REQUEST RECEIVED:\n %s", event)
        LOGGER.info("REQUEST RECEIVED:\n %s", context)
        if event["RequestType"] == "Create":
            LOGGER.info("CREATE!")
            artifact_count = start_artifact_build(
                source_s3=event["ResourceProperties"]["SourceS3URI"],
                source_subfolder=event["ResourceProperties"]["SourceSubfolder"],
                project_name=event["ResourceProperties"]["ProjectName"],
            )
            cfnresponse.send(
                event,
                context,
                cfnresponse.SUCCESS,
                {
                    "response": "Resource update successful!",
                    "ArtifactCount": artifact_count,
                },
            )
        elif event["RequestType"] == "Update":
            LOGGER.info("UPDATE!")
            artifact_count = start_artifact_build(
                source_s3=event["ResourceProperties"]["SourceS3URI"],
                source_subfolder=event["ResourceProperties"]["SourceSubfolder"],
                project_name=event["ResourceProperties"]["ProjectName"],
            )
            cfnresponse.send(
                event,
                context,
                cfnresponse.SUCCESS,
                {
                    "response": "Resource update successful!",
                    "ArtifactCount": artifact_count,
                },
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


# if __name__ == "__main__":

#     source_s3 = "s3://167428594774-us-east-1-aho/build/code/code.zip"
#     source_zip = download_obj_from_s3(source_s3)
#     source_subfolder = "modules/containers"
#     artifacts = get_zipfile_subfolders(source_zip, source_subfolder)

#     print(artifacts)
