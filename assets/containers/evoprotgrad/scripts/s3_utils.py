import boto3
from pathlib import Path
from urllib.parse import urlparse

def download_s3_folder(s3_uri, local_dir=None):
    """
    Download the contents of a folder directory
    Args:
        s3_uri: the s3 uri to the top level of the files you wish to download
        local_dir: a relative or absolute directory path in the local file system
    """
    s3 = boto3.resource("s3")
    bucket = s3.Bucket(urlparse(s3_uri).hostname)
    s3_path = urlparse(s3_uri).path.lstrip('/')
    if local_dir is not None:
        local_dir = Path(local_dir)
    for obj in bucket.objects.filter(Prefix=s3_path):
        target = obj.key if local_dir is None else local_dir / Path(obj.key).relative_to(s3_path)
        target.parent.mkdir(parents=True, exist_ok=True)
        if obj.key[-1] == '/':
            continue
        bucket.download_file(obj.key, str(target))