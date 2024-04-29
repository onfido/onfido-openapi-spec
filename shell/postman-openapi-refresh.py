#!/usr/bin/env python3
import json
import logging
import requests
import sys

from dataclasses import dataclass
from time import sleep
from os import getenv


@dataclass
class Section:
    name: str
    resources: dict


# Division of the resources by Section
# When resource value is set to None, tag will be automatically generated
# from path prefix replacing _ with spaces and capitalising each word
SECTIONS = (
    Section('Core',
            {'applicants': None,
             'documents': None,
             'live_photos': 'Live photos',
             'live_videos': 'Live videos',
             'workflow_runs': None,
             'tasks': None,
             'motion_captures': 'Motion captures',
             'watchlist_monitors': 'Monitors',
             'id_photos': 'ID Photos'
             }),
    Section('Others',
            {'ping': None,
             'webhooks': None,
             'addresses': 'Address Picker',
             'sdk_token': 'Generate SDK Token',
             'repeat_attempts': 'Repeat attempts',
             'extractions': 'Autofill',
             'results_feedback': 'Fraud reporting (ALPHA)',
             'checks': None,
             'reports': None
             })
)


def get_logger() -> logging.Logger:
    root = logging.getLogger()
    root.setLevel(logging.INFO)

    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging.INFO)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    root.addHandler(handler)

    return root


def convert_path(snake_str: str) -> None:
    return " ".join(x.capitalize() for x in snake_str.lower().split("_"))


def patch_spec(input_spec_file: str, output_spec_file: str) -> dict:
    with open(input_spec_file) as input_handler:
        spec_dict = json.load(input_handler)

        for path in spec_dict['paths'].keys():
            path_prefix, resource_name = path.split('/')[1], None

            for section in SECTIONS:
                if path_prefix in section.resources:
                    if not (resource_name := section.resources[path_prefix]):
                        resource_name = convert_path(path_prefix)

                    tag = '{} | {}'.format(section.name, resource_name)
                    break

            if not resource_name:
                logger.warning('Skipping path prefix: {}'.format(path_prefix))
                continue

            for method in spec_dict['paths'][path]:
                spec_dict['paths'][path][method]['tags'] = [tag]

    with open(output_spec_file, 'w') as fp:
        json.dump(spec_dict, fp, indent=2)

    return spec_dict


def update_postman_collection(spec_dict: dict, api_id: str,
                              schema_id: str, file_path: str,
                              collection_id: str = None) -> None:

    postman_base = f"https://api.getpostman.com/apis/{api_id}"

    headers = {'Accept': 'application/vnd.api.v10+json',
               'Content-Type': "application/json",
               'X-API-Key': getenv('POSTMAN_API_KEY')}

    # Update OpenAPI schema
    # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-7ad78218-f1c6-48a6-b612-3cf64cdde475
    result = requests.put(
                url=f"{postman_base}/schemas/{schema_id}/files/{file_path}",
                headers=headers,
                data=json.dumps({
                    "content": json.dumps(spec_dict, indent=2)
                }))

    result.raise_for_status()

    logger.info("API updated")

    if not collection_id:
        # Add collection if collection id wasn't provided
        # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-c70373b3-b7df-4f7e-90a1-f0d0f2fe9370
        result = requests.post(url=f"{postman_base}/collections",
                               headers=headers,
                               data=json.dumps({
                                  "operationType": "GENERATE_FROM_SCHEMA",
                                  "options": {
                                    "folderStrategy": "Tags"
                                    }
                                  }))

        result.raise_for_status()

        logger.info("Collection created")
    else:
        # Or just sync collection, need to Update Collection on Postman though
        # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-4fff4089-9529-41c9-9ceb-58253e5cb342
        result = requests.put(
          f"{postman_base}/collections/{collection_id}/sync-with-schema-tasks",
          headers=headers)

        result.raise_for_status()

        task_id, status = result.json()['taskId'], None

        logger.info(f"Collection re-sync req., waiting for task: {task_id}")

        while (True):
            status = requests.get(url=f"{postman_base}/tasks/{task_id}",
                                  headers=headers).json()['status']

            if status != 'pending':
                break

            sleep(15)

        logger.info(f"Task {task_id} status: {status}")


logger = get_logger()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input-spec.json output-spec.json")
        sys.exit(1)

    try:
        update_postman_collection(
            patch_spec(sys.argv[1], sys.argv[2]),
            api_id=getenv('POSTMAN_API_ID'),
            schema_id=getenv('POSTMAN_SCHEMA_ID'),
            file_path='openapi.json',
            collection_id=getenv('POSTMAN_COLLECTION_ID'))

    except Exception:
        logging.exception("Exception raised!")
        sys.exit(1)
