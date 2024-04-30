#!/usr/bin/env python3
import json
import logging
import requests
import sys

from dataclasses import dataclass
from time import sleep
from os import getenv
from datetime import date


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


logger = get_logger()


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


class PostmanClient:
    def __init__(self, api_id: str):
        self._postman_base = f"https://api.getpostman.com/apis/{api_id}"
        self._headers = {'Accept': 'application/vnd.api.v10+json',
                         'Content-Type': "application/json",
                         'X-API-Key': getenv('POSTMAN_API_KEY')}

    def wait_for_task(self, task_id: str) -> None:
        status = None

        while (True):
            status = requests.get(url=f"{self._postman_base}/tasks/{task_id}",
                                  headers=self._headers).json()['status']

            if status != 'pending':
                break

            sleep(15)

        if status != 'completed':
            raise Exception(f"Unexpected status for task {task_id}: {status}")

    def get_postman_collection_version(self):
        today = date.today()
        return today.strftime("%Y-%m-%d_%H:%M")

    def update_collection(self, spec_dict: dict,
                          schema_id: str, file_path: str,
                          collection_id: str = None) -> None:
        # Update OpenAPI schema
        # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-7ad78218-f1c6-48a6-b612-3cf64cdde475
        result = requests.put(
                    url=f"{self._postman_base}/schemas/"
                        f"{schema_id}/files/{file_path}",
                    headers=self._headers,
                    data=json.dumps({
                        "content": json.dumps(spec_dict, indent=2)
                    }))

        result.raise_for_status()

        logger.info("API updated")

        if not collection_id:
            # Add collection if collection id wasn't provided
            # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-c70373b3-b7df-4f7e-90a1-f0d0f2fe9370
            result = requests.post(url=f"{self._postman_base}/collections",
                                   headers=self._headers,
                                   data=json.dumps({
                                     "operationType": "GENERATE_FROM_SCHEMA",
                                     "options": {
                                      "folderStrategy": "Tags",
                                      "requestParametersResolution": "Example",
                                      "exampleParametersResolution": "Example"
                                     }
                                    }))

            result.raise_for_status()

            logger.info("Collection created")
            # TODO store collection_id
        else:
            # Or just sync collection
            # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-4fff4089-9529-41c9-9ceb-58253e5cb342
            result = requests.put(url=f"{self._postman_base}/collections/"
                                      f"{collection_id}"
                                      "/sync-with-schema-tasks",
                                  headers=self._headers)

            result.raise_for_status()

            self.wait_for_task(task_id=result.json()['taskId'])

        # Publish a new Postman API version
        # https://www.postman.com/postman/workspace/postman-public-workspace/request/12959542-425f4392-7276-4f31-a9c4-abc0922895e0
        postman_collection_version = self.get_postman_collection_version()

        result = requests.post(url=f"{self._postman_base}/versions",
                               headers=self._headers,
                               data=json.dumps({
                                    "name": postman_collection_version,
                                    "releaseNotes": "",
                                    "collections": [
                                        {
                                            "id": f"{collection_id}"
                                        }
                                    ],
                                    "schemas": [
                                        {
                                            "id": f"{schema_id}"
                                        }
                                    ]
                                    }))

        result.raise_for_status()

        print('Url: ',
              'https://god.gw.postman.com/run-collection/{}'.format(
                  result.json()['id']))

# https://god.gw.postman.com/run-collection/221325-8ba05649-fd5b-40eb-976b-bc1d8ef6e328
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input-spec.json output-spec.json")
        sys.exit(1)

    try:
        postman_client = PostmanClient(api_id=getenv('POSTMAN_API_ID'))
        patched_spec = patch_spec(sys.argv[1], sys.argv[2])
        postman_client.update_collection(
            spec_dict=patched_spec,
            schema_id=getenv('POSTMAN_SCHEMA_ID'),
            file_path='openapi.json',
            collection_id=getenv('POSTMAN_COLLECTION_ID'))

    except Exception:
        logger.exception("Exception raised!")
        sys.exit(1)
