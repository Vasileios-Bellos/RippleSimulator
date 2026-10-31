classdef AudioPlayerPoolTest < support.ProjectTestCase
    % AUDIOPLAYERPOOLTEST Verify silent playback ownership and voice reuse.

    properties
        Players
        Pool
    end

    methods (TestMethodSetup)
        function createPlayers(testCase)
            testCase.Players = {audioplayer(zeros(64, 1), 44100), audioplayer(zeros(64, 1), 44100)};
            testCase.Pool = app.internal.audio.PlayerPool(testCase.Players);
            testCase.addTeardown(@() testCase.Pool.close());
        end
    end

    methods (Test, TestTags = {'Integration'})
        function idleVoicesAreAvailable(testCase)
            testCase.verifyTrue(testCase.Pool.isAvailable(1));
            testCase.verifyTrue(testCase.Pool.isAvailable(2));
        end

        function activeVoiceIsReserved(testCase)
            testCase.Pool.play(1);
            testCase.verifyFalse(testCase.Pool.isAvailable(1));
            testCase.verifyTrue(testCase.Pool.isAvailable(2));
        end

        function completedVoiceIsReusable(testCase)
            testCase.Pool.play(1);
            waitForVoice(testCase.Pool, 1);
            testCase.verifyTrue(testCase.Pool.isAvailable(1));
            testCase.Pool.play(1);
            testCase.verifyFalse(testCase.Pool.isAvailable(1));
        end

        function stoppedVoiceIsReusable(testCase)
            testCase.Pool.play(1);
            stop(testCase.Players{1});
            testCase.verifyTrue(testCase.Pool.isAvailable(1));
        end

        function closeReleasesOwnedPlayers(testCase)
            originalTimers = timerfindall();
            testCase.Pool.play(1);
            testCase.Pool.play(2);
            testCase.verifyWarningFree(@() testCase.Pool.close());
            testCase.verifyFalse(isvalid(testCase.Players{1}));
            testCase.verifyFalse(isvalid(testCase.Players{2}));
            testCase.verifyEqual(timerfindall(), originalTimers);
            testCase.verifyWarningFree(@() testCase.Pool.close());
        end
    end
end

function waitForVoice(pool, index)
    started = tic;
    while ~pool.isAvailable(index) && toc(started) < 3
        pause(0.01);
        drawnow;
    end
end
