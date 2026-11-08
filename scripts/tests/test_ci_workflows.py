"""Structural guard for gate.yml / ci.yml and the Jenkins removal (T-159).

Run: python3 -m unittest discover -s scripts/tests -v   (needs PyYAML)
"""
import pathlib
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
WFDIR = ROOT / ".github" / "workflows"


def load(name):
    text = (WFDIR / name).read_text()
    wf = yaml.safe_load(text)
    wf["_on"] = wf.get("on", wf.get(True))  # YAML 1.1 parses `on` as True
    return text, wf


class Gate(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text, cls.wf = load("gate.yml")
        cls.job = next(iter(cls.wf["jobs"].values()))

    def test_reusable_only(self):
        self.assertEqual(set(self.wf["_on"]), {"workflow_call"})
        self.assertEqual(len(self.wf["jobs"]), 1)

    def test_permissions_read_only(self):
        self.assertEqual(self.wf["permissions"], {"contents": "read"})

    def test_timeout(self):
        self.assertEqual(self.job["timeout-minutes"], 10)

    def test_mysql_service(self):
        svc = self.job["services"]["mysql"]
        self.assertEqual(svc["image"], "mysql:8.4")
        self.assertEqual(
            svc["env"],
            {
                "MYSQL_ROOT_PASSWORD": "root",
                "MYSQL_DATABASE": "cv",
                "MYSQL_USER": "cv",
                "MYSQL_PASSWORD": "cv",
            },
        )

    def test_health_check_is_a_real_query_over_tcp(self):
        opts = self.job["services"]["mysql"]["options"]
        self.assertIn("mysql -h127.0.0.1 -ucv -pcv -e 'SELECT 1' cv", opts)
        for frag in (
            "--health-interval 2s",
            "--health-timeout 5s",
            "--health-retries 30",
            "--health-start-period 30s",
        ):
            self.assertIn(frag, opts)

    def test_checkout_without_credentials(self):
        co = [s for s in self.job["steps"] if "actions/checkout" in s.get("uses", "")]
        self.assertEqual(len(co), 1)
        self.assertIs(co[0]["with"]["persist-credentials"], False)

    def test_flyway_step(self):
        runs = [s["run"] for s in self.job["steps"] if "flyway/flyway" in s.get("run", "")]
        self.assertEqual(len(runs), 1)
        run = runs[0]
        self.assertIn("flyway/flyway:13.7.0 migrate", run)
        self.assertIn("--network ${{ job.services.mysql.network }}", run)
        self.assertIn("$GITHUB_WORKSPACE/sql:/flyway/sql", run)
        # Flyway's bundled MariaDB driver hangs silently without this on MySQL 8.
        self.assertIn("jdbc:mysql://mysql:3306/cv?allowPublicKeyRetrieval=true", run)
        for frag in (
            "FLYWAY_USER=cv",
            "FLYWAY_PASSWORD=cv",
            "FLYWAY_LOCATIONS=filesystem:/flyway/sql/migrations",
            "FLYWAY_CONNECT_RETRIES=3",
        ):
            self.assertIn(frag, run)

    def test_no_aws_or_secrets(self):
        self.assertNotIn("secrets.", self.text)
        self.assertNotIn("id-token", self.text)


class Ci(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text, cls.wf = load("ci.yml")

    def test_pull_request_only(self):
        on = self.wf["_on"]
        self.assertEqual(set(on), {"pull_request"})
        self.assertEqual(on["pull_request"]["branches"], ["master"])

    def test_calls_the_gate(self):
        uses = [j.get("uses") for j in self.wf["jobs"].values()]
        self.assertEqual(uses, ["./.github/workflows/gate.yml"])

    def test_permissions_and_concurrency(self):
        self.assertEqual(self.wf["permissions"], {"contents": "read"})
        c = self.wf["concurrency"]
        self.assertIs(c["cancel-in-progress"], True)
        self.assertIn("github.ref", c["group"])


class NoJenkins(unittest.TestCase):
    def test_jenkinsfile_absent(self):
        self.assertFalse((ROOT / "Jenkinsfile").exists())

    def test_no_jenkins_in_any_workflow(self):
        for f in WFDIR.glob("*.yml"):
            self.assertNotIn("jenkins", f.read_text().lower(), f.name)


if __name__ == "__main__":
    unittest.main()
