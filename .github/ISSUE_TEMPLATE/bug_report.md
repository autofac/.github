---
name: Bug Report
about: Create a report to help us fix a problem.
title: ''
labels: ''
assignees: ''
---

<!--
  This is for THIS REPO ONLY. If you are having trouble with core Autofac, file
  an issue in the core Autofac repo. If you're having trouble with an
  integration library like Autofac.Integration.Mvc, Autofac.Multitenant, or
  Autofac.Extensions.DependencyInjection please file in the appropriate repo!

  We have some great troubleshooting and diagnostics docs! They can help you figure
  out what's going on - if you haven't checked them out lately, please do!
  https://autofac.readthedocs.io/en/latest/advanced/debugging.html
-->

## Describe the Bug

<!-- A clear and concise description of what the bug is. -->

## Steps to Reproduce

<!-- Tell us how to reproduce the issue. Ideally provide a failing unit test. -->

```c#
public class ReproTest
{
  [Fact]
  public void Repro()
  {
    var builder = new ContainerBuilder();
    var container = builder.Build();
    Assert.NotNull(container);
  }
}
```

## Expected Behavior

<!-- Describe what you expected to happen. -->

## Exception with Stack Trace

<!-- If you see an exception, put the WHOLE THING here. -->

```text
Put the exception with stack trace here.
```

## Dependency Versions

Autofac: <!-- Fill in the version of core Autofac you're using. -->
<!-- What other dependencies are you using? Names and versions. -->

## Additional Info

<!-- Add any other context about the problem here. -->
