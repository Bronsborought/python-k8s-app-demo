#!/usr/bin/python3

import os

from ansible.module_utils.basic import AnsibleModule


def check_command(module, binary_name, arguments):
    binary_path = module.get_bin_path(binary_name, required=False)

    if binary_path is None:
        return {
            "installed": False,
            "ok": False,
        }

    rc, _, _ = module.run_command([binary_path, *arguments])

    return {
        "installed": True,
        "ok": rc == 0,
    }


def main():
    module = AnsibleModule(
        argument_spec={
            "project_dir": {
                "type": "path",
                "required": True,
            },
            "minikube_profile": {
                "type": "str",
                "default": "minikube",
            },
        },
        supports_check_mode=True,
    )

    project_dir = module.params["project_dir"]
    minikube_profile = module.params["minikube_profile"]

    docker = check_command(module, "docker", ["info"])
    kubectl = check_command(module, "kubectl", ["version", "--client"])
    minikube = check_command(module, "minikube", ["version"])

    runner_listener = os.path.join(
        project_dir,
        "actions-runner",
        "bin",
        "Runner.Listener",
    )

    runner_config = os.path.join(
        project_dir,
        "actions-runner",
        ".runner",
    )

    runner_installed = os.path.isfile(runner_listener)
    runner_configured = os.path.isfile(runner_config)

    bootstrap_ready = all(
        [
            docker["ok"],
            kubectl["ok"],
            minikube["ok"],
            runner_installed,
            runner_configured,
        ]
    )

    module.exit_json(
        changed=False,
        bootstrap_ready=bootstrap_ready,
        checks={
            "docker": docker,
            "kubectl": kubectl,
            "minikube": minikube,
            "github_runner": {
                "installed": runner_installed,
                "configured": runner_configured,
            },
        },
    )


if __name__ == "__main__":
    main()
