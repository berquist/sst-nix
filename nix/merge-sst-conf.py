"""Merge sstsimulator.conf files into one.

Usage: merge-sst-conf.py OUTPUT BINDIR CONF...

Later files win for a key that is in more than one file.  [SSTCore] bindir
is set to BINDIR, because sst-test-core and sst-test-elements run
<bindir>/sst.  A plain concatenation does not work: the test framework
parses the file with configparser, which rejects repeated sections.
"""

import configparser
import sys


def main() -> None:
    output, bindir, *confs = sys.argv[1:]
    merged = configparser.RawConfigParser(interpolation=None)
    # Keys are case sensitive (SST_ELEMENT_LIBRARY_LIBDIR, juno_LIBDIR).
    merged.optionxform = str  # type: ignore[assignment,method-assign]
    for conf in confs:
        part = configparser.RawConfigParser(interpolation=None, strict=False)
        part.optionxform = str  # type: ignore[assignment,method-assign]
        part.read(conf)
        for section in part.sections():
            if not merged.has_section(section):
                merged.add_section(section)
            for key, value in part.items(section):
                merged.set(section, key, value)
    merged.set("SSTCore", "bindir", bindir)
    with open(output, "w") as handle:
        merged.write(handle, space_around_delimiters=False)


if __name__ == "__main__":
    main()
