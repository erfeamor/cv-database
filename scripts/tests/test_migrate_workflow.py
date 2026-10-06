"""Structural guard for .github/workflows/migrate.yml (T-158).

Run: python3 -m unittest discover -s scripts/tests -v   (needs PyYAML)
"""
import pathlib
import unittest

import yaml

WF = pathlib.Path(__file__).resolve().parents[2] / ".github" / "workflows" / "migrate.yml"


class MigrateWorkflow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = WF.read_text()
        cls.wf = yaml.safe_load(cls.text)
        cls.jobs = cls.wf["jobs"]

    def test_triggers_exact(self):
        on = self.wf.get("on", self.wf.get(True))  # YAML 1.1 parses `on` as True
        self.assertEqual(set(on), {"push", "workflow_dispatch"})
        self.assertEqual(on["push"]["branches"], ["master"])
        self.assertEqual(
            sorted(on["push"]["paths"]),
            sorted(["sql/migrations/**", ".github/workflows/migrate.yml"]),
        )

    def test_permissions_minimal(self):
        self.assertEqual(
            self.wf["permissions"],
            {"id-token": "write", "contents": "read", "statuses": "read"},
        )
        for job in self.jobs.values():
            if "permissions" in job:
                self.assertLessEqual(
                    set(job["permissions"]), {"id-token", "contents", "statuses"}
                )

    def test_concurrency_queues(self):
        c = self.wf["concurrency"]
        self.assertEqual(c["group"], "migrate-cv-database")
        self.assertIs(c["cancel-in-progress"], False)

    def test_job_order_and_timeouts(self):
        self.assertEqual(set(self.jobs), {"wait-for-jenkins", "migrate"})
        self.assertEqual(self.jobs["migrate"]["needs"], "wait-for-jenkins")
        for name, job in self.jobs.items():
            self.assertIsInstance(job.get("timeout-minutes"), int, name)

    def test_master_ref_guard(self):
        # workflow_dispatch can run from any ref: both jobs must fail (not skip)
        # on the first step unless the ref is master.
        for name, job in self.jobs.items():
            first = str(job["steps"][0])
            self.assertIn("GITHUB_REF", first, name)
            self.assertIn("refs/heads/master", first, name)

    def test_aws_interface(self):
        env = self.wf["env"]
        self.assertEqual(env["SSM_DOCUMENT"], "cv-redeploy-migrate")
        self.assertEqual(env["TARGET_NAME_TAG"], "cv-project-domain-service")
        self.assertEqual(env["AWS_REGION"], "eu-west-3")
        self.assertEqual(env["JENKINS_CONTEXT"], "continuous-integration/jenkins/branch")
        self.assertIn("vars.AWS_DEPLOY_ROLE_ARN", self.text)
        self.assertNotIn("secrets.", self.text)
        self.assertNotIn("pull_request_target", self.text)


if __name__ == "__main__":
    unittest.main()
