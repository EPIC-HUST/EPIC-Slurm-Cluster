"""Regression checks for onboarding without rewriting existing quotas."""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ansible" / "filter_plugins"))
from disk_quota import quota_limits_differ


class DiskQuotaTests(unittest.TestCase):
    def test_onboarding_changes_only_new_user(self):
        for deadline in (1, 2000000000):  # Expired and active grace periods.
            report = (
                "*** Report for user quotas on device /dev/sda\n"
                "Block grace time: 3days; Inode grace time: 3days\n"
                f"#10001 +- 150 100 200 {deadline} 10 0 0 0\n"
                "#10002 -- 0 100 200 0 0 0 0 0\n"
            )
            changed = [uid for uid in (10001, 10002, 10003)
                       if quota_limits_differ(report, uid, 100, 200)]
            self.assertEqual(changed, [10003])

    def test_policy_change_and_inode_drift_are_applied(self):
        report = "#10001 -- 0 100 200 0 0 0 0 0"
        self.assertTrue(quota_limits_differ(report, 10001, 110, 200))
        self.assertTrue(quota_limits_differ(report, 10001, 100, 220))
        self.assertTrue(quota_limits_differ(
            "#10001 -+ 0 100 200 0 20 10 30 1", 10001, 100, 200))

    def test_zero_usage_and_unlimited_records(self):
        self.assertFalse(quota_limits_differ(
            "10001 -- 0 100 200 0 0 0 0 0", "10001", "100", "200"))
        self.assertTrue(quota_limits_differ(
            "#10001 -- 0 0 0 0 0 0 0 0", 10001, 100, 200))

    def test_invalid_records_fail_before_writing(self):
        for report in ("#10001 +- 150 100 200 none 10 0 0 0",
                       "#10001 +- 150 100 200",
                       "#10001 -- 0 100 200 0 0 0 0 0\n" * 2):
            with self.assertRaises(ValueError):
                quota_limits_differ(report, 10001, 100, 200)


if __name__ == "__main__":
    unittest.main()
