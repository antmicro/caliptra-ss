# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import logging as log
import os
from pathlib import Path

import hjson
import yaml

logger = log.getLogger(__name__)


def get_yaml_list(test_suite_path):
    yaml_list = []
    for root, _, files in os.walk(test_suite_path):
        for f in files:
            f = Path(root) / Path(f)
            if f.match("*.yml") or f.match("*.yaml"):
                yaml_list.append(f)
    return yaml_list


def get_testpoints_from_yamls(yaml_list):
    testpoints = {}
    for yaml_file in yaml_list:
        parent = yaml_file.parent.name
        testpoints.setdefault(parent, [])
        with open(yaml_file, "r") as f:
            data = yaml.load(f, Loader=yaml.SafeLoader)
            testpoints[parent].append(data.get("testname"))
    return testpoints


def get_testpoints_from_hjson(hjson_path):
    testpoints = {}

    with open(hjson_path, "r") as f:
        testplan = hjson.load(f)
        # print(testplan)
        try:
            hjson_testpoints = testplan["testpoints"]
        except KeyError:
            log.error("Provided testplan does not contain 'testpoints' field")
            exit(1)

        for testpoint in hjson_testpoints:
            testpoints[testpoint["name"]] = testpoint["tests"]

    return testpoints


def validate_testpoints(testpoints_1, testpoints_2):
    mismatches = {}
    for key, values in testpoints_1.items():
        try:
            testpoints_2[key]
        except KeyError:
            # Whole test was not found, insert to mismatches
            mismatches.setdefault(key, values)
            continue

        if sorted(testpoints_2[key]) != sorted(values):
            # Key exists but values do not match, insert to mismatches
            mismatches.setdefault(key, values)

    no_of_mismatches = len(mismatches)
    if no_of_mismatches:
        log.error("Testplan is not compatible with test suite, testpoints differ at:")
        for miss in mismatches:
            log.error(miss)
    else:
        log.info("Testplan matches test suite")

    return no_of_mismatches


def gen_hjson(testplan_name, testpoints, hjson_path):
    testplan = {
        "name": testplan_name,
        "testpoints": [],
    }

    for name, testnames in sorted(testpoints.items()):
        testpoint = {
            "name": name,
            "desc": "",
            "stage": "",
            "tests": list(
                set(testnames)
            ),  # Remove repetitions by converting to set and back to list
        }
        testplan["testpoints"].append(testpoint)

    with open(hjson_path, "w") as f:
        hjson.dump(testplan, f)

    log.info(f"Testplan generated successfully at {hjson_path}")


def main():
    log.basicConfig(level=log.INFO)
    parser = argparse.ArgumentParser(
        prog="process_test_suite",
        description="Generate or validate a HJSON testplan from the existing test suite with yaml descriptors",
    )
    parser.add_argument(
        "-s",
        "--test_suite",
        type=Path,
        help="Path to the directory containing directories with test yamls",
    )
    parser.add_argument(
        "-t",
        "--testplan_hjson",
        type=Path,
        default=None,
        required=False,
        help="Path to the testplan HJSON file to generate or validate",
    )
    parser.add_argument(
        "-n",
        "--testplan_name",
        type=str,
        required=False,
        default="Caliptra SS Testplan",
        help="Name of the generated testplan",
    )
    parser.add_argument(
        "--validate",
        required=False,
        action="store_true",
        help="Validate existing HJSON against the test suite",
    )
    args = parser.parse_args()

    test_suite_path = args.test_suite
    testplan_path = args.testplan_hjson
    testplan_name = args.testplan_name
    do_validate = args.validate

    if not test_suite_path.exists():
        log.error("Test suite path does not exist")
        return 1
    elif not test_suite_path.is_dir():
        log.error("Test suite path does not point to directory")
        return 1

    if not testplan_path.exists() and do_validate:
        log.error("Testplan HJSON does not exist, unable to validate")
        return 1

    if testplan_path.exists() and testplan_path.is_dir():
        log.error("Testplan HJSON path is a directory")
        return 1

    yaml_list = get_yaml_list(test_suite_path)
    yaml_testpoints = get_testpoints_from_yamls(yaml_list)

    if do_validate:
        hjson_testpoints = get_testpoints_from_hjson(testplan_path)
        return validate_testpoints(yaml_testpoints, hjson_testpoints)
    else:
        gen_hjson(testplan_name, yaml_testpoints, testplan_path)


if __name__ == "__main__":
    exit(main())
