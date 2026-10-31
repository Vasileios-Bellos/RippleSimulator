classdef (Sealed) PlayerPool < handle
    % PLAYERPOOL Retain audio players until their completion callbacks finish.

    properties (Access = private)
        Players (1, :) cell
        Active (1, :) logical
        Closing (1, 1) logical = false
        ReleaseReady (1, 1) logical = false
    end

    methods
        function obj = PlayerPool(players)
            arguments
                players (1, :) cell
            end
            obj.Players = players;
            obj.Active = false(size(players));
            for index = 1:numel(players)
                players{index}.StartFcn = @(~, ~) obj.started(index);
                players{index}.StopFcn = @(~, ~) obj.completed(index);
            end
        end

        function play(obj, index)
        % PLAY Reserve a voice before requesting asynchronous playback.
            arguments
                obj (1, 1) app.internal.audio.PlayerPool
                index (1, 1) double {mustBeInteger, mustBePositive}
            end
            if obj.Closing
                return
            end
            obj.Active(index) = true;
            try
                play(obj.Players{index});
            catch exception
                obj.Active(index) = false;
                rethrow(exception);
            end
        end

        function value = isAvailable(obj, index)
        % ISAVAILABLE Require completion before reusing a playback voice.
            arguments
                obj (1, 1) app.internal.audio.PlayerPool
                index (1, 1) double {mustBeInteger, mustBePositive}
            end
            value = ~obj.Closing && ~obj.Active(index) && isvalid(obj.Players{index}) ...
                && ~isplaying(obj.Players{index});
        end

        function close(obj)
        % CLOSE Stop all voices and release completed players.
            if obj.Closing
                return
            end
            obj.Closing = true;
            for index = 1:numel(obj.Players)
                player = obj.Players{index};
                if isvalid(player) && isplaying(player)
                    stop(player);
                end
            end
            drawnow;
            obj.ReleaseReady = true;
            for index = 1:numel(obj.Players)
                if ~obj.Active(index)
                    obj.release(index);
                end
            end
        end
    end

    methods (Access = private)
        function started(obj, index)
            obj.Active(index) = true;
        end

        function completed(obj, index)
            obj.Active(index) = false;
            if obj.ReleaseReady
                obj.release(index);
            end
        end

        function release(obj, index)
            player = obj.Players{index};
            if ~isempty(player) && isvalid(player)
                player.StartFcn = [];
                player.StopFcn = [];
                delete(player);
            end
            obj.Players{index} = [];
        end
    end
end
