classdef (Sealed) ImageAnimationTest < support.ProjectTestCase
    % IMAGEANIMATIONTEST Verify reflected fields across circular-storage reuse.

    properties (TestParameter)
        Resolution = struct(WholeArray=101, Blocked=401)
    end

    properties
        Response
    end

    methods (TestClassSetup)
        function prepareResponse(testCase)
            setup = app.internal.simulation.defaultSetup();
            testCase.Response = app.internal.responses.ImageResponse( ...
                setup.Fluid, setup.Source, setup.DomainSize, 0.5, 10, 101);
        end
    end

    methods (Test, TestTags = {'Integration'})
        function recycledColumnsRetainFields(testCase, Resolution)
            [animation, events] = prepareSequence(testCase.Response, Resolution);
            time = 151*animation.Step;

            animation = animation.advanceTo(time);
            actual = animation.sample(events);
            expected = directField(testCase.Response, events, time, Resolution);

            testCase.verifyEqual(animation.SourceCount, 3);
            testCase.verifyEqual(actual, expected, AbsTol=5e-10);
            testCase.verifyGreaterThan(max(abs(expected), [], "all"), 0);
        end

        function recycledColumnsSettleExactly(testCase, Resolution)
            [animation, events] = prepareSequence(testCase.Response, Resolution);

            animation = animation.advanceTo(events(end).Time+animation.Duration);
            actual = animation.sample(events);

            testCase.verifyEqual(animation.SourceCount, 0);
            testCase.verifyEqual(actual, zeros(Resolution), AbsTol=0);
        end
    end
end

function [animation, events] = prepareSequence(response, resolution)
    coordinates = linspace(-response.DomainSize/2, response.DomainSize/2, resolution);
    animation = app.internal.playback.PreparedImageAnimation(response, resolution, 10, 0);
    positions = response.DomainSize*[0, 0; 0.2, -0.1; -0.3, 0.1];
    times = animation.Step*[0, 3.7, 76.3];
    events = repmat(struct(Id=0, Time=0, Strength=0.1, Mapping=[]), 1, 3);
    for index = 1:3
        mapping = response.mapPosition(coordinates, positions(index, :), Inf);
        events(index) = struct(Id=index, Time=times(index), Strength=0.1, Mapping=mapping);
        animation = animation.add(times(index), 0.1, mapping, index);
    end
end

function elevation = directField(response, events, time, resolution)
    elevation = zeros(resolution);
    for event = events
        age = time-event.Time;
        envelope = app.internal.responses.SettlingEnvelope.sample(age, response.TimeScale, 10);
        elevation = elevation+event.Strength*envelope*response.sample(event.Mapping, age);
    end
end
