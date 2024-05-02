#!/usr/bin/env python3
import json
import logging
import requests
import sys

from os import getenv
from collections import defaultdict

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()


def nest_collection(postman_collection: dict) -> None:
    patched_items = defaultdict(list)

    for item in postman_collection['item']:
        folder_name, subfolder_name = map(str.strip,
                                          item['name'].split('|', 2))

        item['name'] = subfolder_name
        patched_items[folder_name].append(item)

    postman_collection['item'] = [{
            "name": folder_name,
            "description": "",
            "item": folder_contents
    } for folder_name, folder_contents in patched_items.items()]


def replace_collection(postman_collection_file: str,
                       collection_id: str) -> None:
    headers = {'Accept': 'application/vnd.api.v10+json',
               'Content-Type': "application/json",
               'X-API-Key': getenv('POSTMAN_API_KEY')}

    with open(postman_collection_file) as postman_collection_str:
        postman_collection = json.load(postman_collection_str)
        nest_collection(postman_collection)

        # Replace a collection's data
        # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-bc8b292b-ffbb-4c67-a2a1-2fc416e2aef8
        result = requests.put(
                    url=f"https://api.getpostman.com/collections/{collection_id}",
                    headers=headers,
                    data=json.dumps({
                        "collection": postman_collection
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
