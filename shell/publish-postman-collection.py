#!/usr/bin/env python3
import json
import logging
import requests
import sys

from os import getenv


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()


def replace_collection(postman_collection: str, collection_id: str) -> None:
    headers = {'Accept': 'application/vnd.api.v10+json',
               'Content-Type': "application/json",
               'X-API-Key': getenv('POSTMAN_API_KEY')}

    with open(postman_collection) as postman_collection:
        # Replace a collection's data
        # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-bc8b292b-ffbb-4c67-a2a1-2fc416e2aef8
        result = requests.put(
                    url=f"https://api.getpostman.com/collections/{collection_id}",
                    headers=headers,
                    data=json.dumps({
                        "collection": json.load(postman_collection)
                    }))

        result.raise_for_status()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} postman-collection-v2.json collection_id")
        sys.exit(1)

    try:

        replace_collection(sys.argv[1], sys.argv[2])
        logger.info("Collection replaced")

    except Exception:
        logger.exception("Exception raised!")
        sys.exit(2)
