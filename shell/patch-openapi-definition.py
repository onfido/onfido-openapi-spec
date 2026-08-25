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
             'biometric_tokens': 'Biometric tokens',
             'watchlist_monitors': 'Monitors',
             'complyadvantage_watchlists': 'ComplyAdvantage Watchlists',
             'id_photos': 'ID Photos',
             'signing_documents': 'Signing documents',
             'qualified_electronic_signature': 'Qualified Electronic Signature',
             'advanced_electronic_signature': 'Advanced Electronic Signature',
             'simple_electronic_signature': 'Simple Electronic Signature',
             'timeline_file': 'Timeline Files',
             'passkeys': 'Passkeys'
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

# Path[3] which should be promoted to section
# e.g. /workflow_runs/:workflow_run_id/tasks -> Tasks
PROMOTED_PATH = ('tasks', 'timeline_file')


PLACEHOLDER_UUID = '00000000-0000-0000-0000-000000000000'

# Sensible example values for common string fields that lack an explicit example.
# Keys are property names; the value is injected as the "example" when the schema
# is type: string with no format and no existing example.
PLACEHOLDER_STRINGS = {
    # Applicant (from public docs example response)
    'first_name': 'Jane',
    'last_name': 'Doe',
    'applicant_first_name': 'Jane',
    'applicant_last_name': 'Doe',
    'email': 'jane.doe@example.com',
    'phone_number': '+44 7911 123456',
    'customer_user_id': 'customer-12345',
    # Address (from public docs example response)
    'flat_number': '3',
    'building_number': '29',
    'building_name': 'Albert Court',
    'street': 'Second Street',
    'sub_street': '',
    'town': 'London',
    'state': 'TX',
    'postcode': 'SW4 6EH',
    'line1': '29 Second Street',
    'line2': 'Albert Court',
    'line3': '',
    # US Driving Licence
    'id_number': 'D1234567',
    'issue_state': 'CA',
    'address_line_1': '100 Main Street',
    'address_line_2': 'Apt 4B',
    'city': 'San Francisco',
    'postal_code': '94105',
    'middle_name': 'Mary',
    'name_suffix': 'Jr',
    # Location (from public docs example response)
    'ip_address': '127.0.0.1',
    # Document
    'issuing_country': 'GBR',
    'file_type': 'png',
    'side': 'front',
    # SDK token
    'referrer': 'https://*.example.com/*',
    'application_id': 'com.example.app',
    # Webhook
    'url': 'https://example.com/webhooks/onfido',
    # ID numbers
    'value': 'AB123456C',
    'state_code': 'CA',
}

# Example values keyed by schema format (takes precedence over field name)
PLACEHOLDER_FORMATS = {
    'uuid': PLACEHOLDER_UUID,
}


def add_schema_examples(spec_dict, parent_key=None):
    """
    Recursively find any type: string schema that lacks an example and inject
    a safe placeholder based on format or property name. This prevents Postman's
    secret scanner from flagging auto-generated UUIDs and produces readable
    example payloads.
    """
    if isinstance(spec_dict, dict):
        if spec_dict.get('type') == 'string' and 'example' not in spec_dict:
            fmt = spec_dict.get('format')
            if fmt in PLACEHOLDER_FORMATS:
                spec_dict['example'] = PLACEHOLDER_FORMATS[fmt]
            elif (fmt is None
                    and 'enum' not in spec_dict
                    and parent_key in PLACEHOLDER_STRINGS):
                spec_dict['example'] = PLACEHOLDER_STRINGS[parent_key]

        for key, value in spec_dict.items():
            add_schema_examples(value, parent_key=key)
    elif isinstance(spec_dict, list):
        for item in spec_dict:
            add_schema_examples(item, parent_key=parent_key)


def convert_path(snake_str: str) -> None:
    return " ".join(x.capitalize() for x in snake_str.lower().split("_"))


def patch_spec(input_spec_file: str, output_spec_file: str) -> dict:
    with open(input_spec_file) as input_handler:
        spec_dict = json.load(input_handler)

        for path in spec_dict['paths'].keys():
            splitted_path, resource_name = path.split('/'), None

            if len(splitted_path) > 3 and splitted_path[3] in PROMOTED_PATH:
                path_prefix = splitted_path[3]
            else:
                path_prefix = splitted_path[1]

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
        add_schema_examples(spec_dict)
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
