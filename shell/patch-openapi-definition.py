#!/usr/bin/env python3
import json
import logging
import sys

from dataclasses import dataclass

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()


@dataclass
class Section:
    name: str
    resources: dict


# Division of the resources by Section
# When resource value is set to None, tag will be automatically generated
# from path prefix replacing _ with spaces and capitalising each word
SECTIONS = (
    Section('Core Resources',
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
    Section('Other Endpoints',
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


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} input-spec.json output-spec.json")
        sys.exit(1)

    try:
        patched_spec = patch_spec(sys.argv[1], sys.argv[2])
        logger.info("OpenAPI JSON patched")

    except Exception:
        logger.exception("Exception raised!")
        sys.exit(2)
