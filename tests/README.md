# Tests

Run the complete suite from the project folder:

```matlab
results = runtests("tests", IncludeSubfolders=true);
assertSuccess(results);
```

The suite uses `matlab.unittest.TestCase` classes. `assertSuccess` throws an
exception if a test fails, so automated runs report failure to their caller.
See the [MathWorks documentation](https://www.mathworks.com/help/matlab/ref/matlab.unittest.testresult.assertsuccess.html)
for more details.

The Unit tests cover physical limits, fluid properties, elapsed-time behavior,
and packaged audio. The Integration tests cover source superposition, boundary
conditions, material selection, graphics retention, timer cleanup, and the
examples' wave-field histories and dispersion data.

```matlab
results = runtests("tests", IncludeSubfolders=true, Tag="Unit");
assertSuccess(results);
```

Application tests create hidden figures and release their owned resources.
The `support` namespace contains the shared test base class and a controllable
clock for reproducible timing checks.
