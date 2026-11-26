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
  https://docs.autofac.org/en/latest/troubleshooting/index.html

  Keep it short. A failing test and the full stack trace tell us more than a
  long explanation. If an AI tool helped you investigate, report only what you
  confirmed yourself.
-->

## Describe the Bug

<!-- One or two sentences: what happened. -->

## Steps to Reproduce

<!-- The smallest failing unit test you can write. -->

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

<!-- One or two sentences: what you expected instead. -->

## Exception with Stack Trace

<!-- If you see an exception, paste the WHOLE THING here as text. -->

```text
Put the exception with stack trace here.
```

## Dependency Versions

Autofac: <!-- Fill in the version of core Autofac you're using. -->
<!-- What other dependencies are you using? Names and versions, plus the .NET runtime. -->

## Additional Info

<!-- Anything else a maintainer needs. Delete this section if there is nothing. -->
