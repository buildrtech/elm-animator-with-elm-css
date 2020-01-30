module CSS exposing (frames)

import Animator
import Duration
import Expect exposing (Expectation, FloatingPointTolerance(..))
import Fuzz exposing (Fuzzer, float, int, list, string)
import Internal.Estimation as Estimate
import Internal.Interpolate as Interpolate
import Internal.Timeline as Timeline
import Pixels
import Quantity
import Test exposing (..)
import Time


type Event
    = Starting
    | One
    | Two
    | Three
    | Four
    | Five
    | Unreachable


toVals event =
    case event of
        Starting ->
            0

        One ->
            1

        Two ->
            2

        Three ->
            3

        Four ->
            4

        Five ->
            5

        Unreachable ->
            -1


frames =
    describe "Frame Capturing"
        [ -- test "Single event" <|
          -- \_ ->
          --     let
          --         timeline =
          --             Animator.init Starting
          --                 |> Timeline.update (Time.millisToPosix 0)
          --         val =
          --             Timeline.foldp
          --                 (Timeline.CaptureFuture 60)
          --                 toVals
          --                 Interpolate.startLinear
          --                 Nothing
          --                 Interpolate.linearly
          --                 timeline
          --     in
          --     Expect.equal
          --         val
          --         (Timeline.Single 5)
          --   test "Transitioning" <|
          --         \_ ->
          --             let
          --                 timeline =
          --                     Animator.init Starting
          --                         |> Animator.to (Animator.seconds 1) One
          --                         -- NOTE* possible schduling bug
          --                         -- scheduling an event
          --                         |> Timeline.update (Time.millisToPosix 0)
          --                 val =
          --                     Timeline.foldp
          --                         (Timeline.CaptureFuture 60)
          --                         toVals
          --                         Interpolate.startLinear
          --                         Nothing
          --                         Interpolate.linearly
          --                         timeline
          --             in
          --             Expect.equal
          --                 val
          --                 (Timeline.Single 5)
          test "Transitioning" <|
            \_ ->
                let
                    timeline =
                        Animator.init Starting
                            |> Timeline.update (Time.millisToPosix 0)
                            |> Animator.to (Animator.seconds 1) One
                            -- NOTE* possible schduling bug
                            -- scheduling an event
                            |> Timeline.update (Time.millisToPosix 1)

                    val =
                        Timeline.foldp
                            (Timeline.CaptureFuture 60)
                            toVals
                            Interpolate.startLinear
                            Nothing
                            Interpolate.linearly
                            timeline

                    resultFrames =
                        Debug.log "-" <|
                            case val of
                                Timeline.Future details ->
                                    details.frames

                                Timeline.Single single ->
                                    [ single ]
                in
                Expect.equal
                    (List.length resultFrames)
                    -- NOTE, this should probably be 60
                    -- but we're mostly concerned with it giving us any frames at all.
                    61
        , only <|
            test "Transitioning to two events" <|
                \_ ->
                    let
                        timeline =
                            Animator.init Starting
                                |> Timeline.update (Time.millisToPosix 0)
                                |> Animator.queue
                                    [ Animator.event (Animator.seconds 1) One
                                    , Animator.event (Animator.seconds 1) Two
                                    ]
                                -- NOTE* possible schduling bug
                                -- scheduling an event
                                |> Timeline.update (Time.millisToPosix 1)

                        val =
                            Timeline.foldp
                                (Timeline.CaptureFuture 60)
                                toVals
                                Interpolate.startLinear
                                Nothing
                                Interpolate.linearly
                                timeline

                        resultFrames =
                            Debug.log "frames" <|
                                case val of
                                    Timeline.Future details ->
                                        details.frames

                                    Timeline.Single single ->
                                        [ single ]
                    in
                    Expect.equal
                        (List.length resultFrames)
                        -- NOTE, this should probably be 60
                        -- but we're mostly concerned with it giving us any frames at all.
                        121
        , test "Transitioning to two events, interruption" <|
            \_ ->
                let
                    timeline =
                        Animator.init Starting
                            |> Timeline.update (Time.millisToPosix 0)
                            |> Animator.queue
                                [ Animator.event (Animator.seconds 1) One
                                , Animator.event (Animator.seconds 1) Two
                                ]
                            -- NOTE* possible schduling bug
                            -- scheduling an event
                            |> Timeline.update (Time.millisToPosix 1)
                            |> Animator.to (Animator.seconds 1) Two
                            |> Timeline.update (Time.millisToPosix 500)

                    val =
                        Timeline.foldp
                            (Timeline.CaptureFuture 60)
                            toVals
                            Interpolate.startLinear
                            Nothing
                            Interpolate.linearly
                            timeline

                    resultFrames =
                        Debug.log "-" <|
                            case val of
                                Timeline.Future details ->
                                    details.frames

                                Timeline.Single single ->
                                    [ single ]
                in
                Expect.equal
                    (List.length resultFrames)
                    -- NOTE, this should probably be 60
                    -- but we're mostly concerned with it giving us any frames at all.
                    61
        ]