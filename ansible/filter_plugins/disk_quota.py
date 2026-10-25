"""Compare live repquota limits before writing user quota records."""

import re


def quota_limits_differ(report, uid, soft, hard):
    """Read `repquota -u -n -p -v`; grace timestamps never affect this decision."""
    limits = {}
    for line in report.splitlines():
        fields = line.split()
        if not fields or not fields[0].lstrip("#").isdigit():
            continue
        if (
            len(fields) != 10
            or re.fullmatch(r"[-+]{2}", fields[1]) is None
            or not all(value.isdigit() for value in fields[2:])
        ):
            raise ValueError(f"Unexpected repquota user record: {line}")
        identifier = int(fields[0].lstrip("#"))
        if identifier in limits:
            raise ValueError(f"Duplicate repquota UID: {identifier}")
        limits[identifier] = tuple(int(fields[index]) for index in (3, 4, 7, 8))
    # No record means no usage or limits; newly created users need initialization.
    return limits.get(int(uid), (0, 0, 0, 0)) != (int(soft), int(hard), 0, 0)


class FilterModule:
    def filters(self):
        return {"quota_limits_differ": quota_limits_differ}
