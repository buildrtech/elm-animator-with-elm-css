module Playground.Timeline exposing (main)


{- Timeline Playground!


This is for getting a visual representation of a timeline.


    1. Plot all events on a symbolic timeline
        - Plot unvisitable events as well, just have them be a separate style.
        - Only event names as labels
        - More data as tooltips

    2. Scrub through timeline
        - Set the current time of the timeline without updating it.
            - can't go before last hard update
        - See current, prev, upcoming, arrived vals
        - See generated CSS
        - See what the timeline would be if we updated


----

    3. See actual rendered values on the timeline
        - Plot the bezier splines
        - Plot the actual values at regular intervals


-}

import Browser
import Html exposing (Html, button, div, h1, text)
import Html.Attributes as Attr
import Html.Events exposing (onClick)
import Svg
import Svg.Attributes as SvgA
import Internal.Spring as Spring
import Internal.Timeline as Timeline
import Duration
import Internal.Interpolate as Interpolate
import Internal.Bezier as Bezier
import Internal.Css as Css
import Animator
import Time
import Internal.Time as Time

main =
    Browser.document
        { init =
            \() ->
                ( { timeline = 
                    Animator.init (State 0)
                        |> Animator.queue
                            [ Animator.event (Animator.seconds 1) (State 1)
                            , Animator.event (Animator.seconds 1) (State 2)
                            , Animator.event (Animator.seconds 1) (State 3)
                            ]
                        |> Timeline.update (Time.millisToPosix 0)
                        |> Animator.interrupt 
                            [ Animator.event (Animator.seconds 1) (State 4)
                            , Animator.event (Animator.seconds 1) (State 5)
                            , Animator.event (Animator.seconds 1) (State 6)
                            ]
                        |> Timeline.update (Time.millisToPosix 1500)
                  , lastUpdated = Time.millisToPosix 0
                  , tooltip = Nothing
                  }
                , Cmd.none
                )
        , view = view
        , update = update
        , subscriptions = 
            \_ -> Sub.none
        }

type alias Model =
    { timeline : Animator.Timeline State
    , lastUpdated : Time.Posix
    , tooltip : Maybe Tooltip
    }

type alias Tooltip =
    { anchor : Interpolate.Point
    , text : List (String, String)
    }


type State = State Int

type Msg 
    = ScrubTo Time.Posix
    | TooltipShow Tooltip
    | TooltipClear



update msg model =
    case msg of
        ScrubTo time ->
            (model, Cmd.none)

        TooltipShow tooltip ->
            ({ model | tooltip = Just tooltip },Cmd.none)

        TooltipClear ->
            ({ model | tooltip = Nothing },Cmd.none)



type Style = Highlight | Normal | Faded


view model =
    { title = "Timeline Playground"
    , body = [ viewBody model ]
    }


onGrid column row =
    { x = (100 * column) + 50
    , y = (100 * row) + 50
    }

viewBody model =
    div []
        [ h1 [] [ text "Timeline Playground" ]
        , case model.tooltip of 
            Nothing ->
                Html.text ""

            Just tooltip ->
                Html.div 
                    [ Attr.style "position" "absolute"
                    , Attr.style "right" "100px"
                    , Attr.style "top" "100px"
                    ] 
                    (List.map 
                        (\(name, val) -> 
                            Html.div []
                                [ Html.text name
                                , Html.text ": "
                                , Html.text val
                                ]
                        ) 
                        tooltip.text
                    )
        , Svg.svg
            [ SvgA.width "97%"
            , SvgA.height "850px"
            , SvgA.viewBox "0 0 1000 1000"
            , SvgA.style "border: 4px dashed #eee;"
            ]
            [ viewTimeline model.timeline
            --     line Faded 
            --     (onGrid 0 0)
            --     (onGrid 1 0)
            -- , line Normal
            --     { x = 50
            --     , y = 250
            --     }
            --     { x = 200
            --     , y = 250
            --     }
            -- , line Highlight
            --     { x = 50
            --     , y = 550
            --     }
            --     { x = 200
            --     , y = 550
            --     }

            -- , dot Faded 
            --     { x = 50
            --     , y = 50
            --     }

            -- , dot Normal
            --     { x = 50
            --     , y = 550
            --     }
            --  , dot Highlight
            --     { x = 200
            --     , y = 250
            --     }
            ]
        ]

viewTimeline (Timeline.Timeline timeline) =
    Svg.g [] 
        (case timeline.events of
            Timeline.Timetable lines ->
                case Debug.log "lines" lines of
                    [] ->
                        [ Svg.text "whoops, nothing here" ]
                    (top :: remaining) ->
                        let
                            rendered =
                                viewLines timeline.now top remaining
                                    { timeMap = Timemap []
                                    , row = 0
                                    , rendered = []
                                    }
                        in
                        List.reverse rendered.rendered
        )


type Timemap =
    Timemap (List (Time.Absolute, Float))


{-|

-}
lookup : Time.Absolute -> Timemap -> (Timemap, Float)
lookup time (Timemap timemap) =
    
    -- Debug.log "map" <|
        case timemap of
            [] ->
                (Timemap [(time, 0)], 0)
            (lastTime, lastVal) :: remain ->
                if Time.thisAfterThat time lastTime then
                    ( Timemap ((time, lastVal + 1):: timemap)
                    , lastVal + 1
                    )
                else if lastTime == time then
                    ( Timemap timemap
                    , lastVal
                    )

                else
                    let
                        _ = Debug.log "lookup" (time, timemap)

                    in
                    ( Timemap timemap
                    , lookupHelper time timemap
                    )


lookupHelper time timemap =
    case timemap of
        [] ->
            0
        (lastTime, lastVal) :: remain ->
            if Debug.log "eq" <| Time.equal lastTime time then
                lastVal
            else 
                case remain of
                    [] ->
                        0
                    (prevTime, prevValue) :: _ ->
                        
                        if (Time.thisBeforeThat time lastTime  && Time.thisAfterThat time prevTime) then
                            prevValue + 
                                progress
                                    (Time.inMilliseconds prevTime)
                                    (Time.inMilliseconds lastTime)
                                    (Time.inMilliseconds time)

                        else 
                            lookupHelper time remain



progress low high middle =
    (middle - low) 
        / (high - low )



viewLines now (Timeline.Line startsAt first rest) lines cursor =
    let
        newCursor = 
            renderLine now startsAt first rest cursor

    in
    case lines of
        [] ->
            newCursor

        (next :: upcoming) ->
            { newCursor | row = newCursor.row + 1 }
                |> viewRowTransition next newCursor.row
                |> viewLines now next upcoming 
            
    
viewRowTransition (Timeline.Line startsAt first rest) startingRow cursor =
    let
        (newTimemap, start) =
            position 
                startsAt
                { cursor | row = startingRow }

        (finalTimemap, end) =
            position 
                (Timeline.startTime first)
                { cursor | timeMap = newTimemap }


        midOne =
            { x = start.x + ((end.x - start.x) / 2)
            , y = start.y
            }

        midTwo =
            { x = end.x - ((end.x - start.x) / 2)
            , y = end.y
            }

    in
    { row = cursor.row
    , timeMap = finalTimemap
    , rendered = 
        dot Normal start
            :: curve Faded 
                start
                midOne
                midTwo
                end
            
            :: cursor.rendered
    }

renderLine now startsAt first rest cursor =
    let
        transitions =
            List.map2 Tuple.pair
                (first :: rest)
                rest

        newCursor =
            List.foldl (renderTransition now) cursor transitions
            
    in
    List.foldl (renderEvent now) newCursor rest
        |> renderEvent now first
          
        

position time cursor =
    let
        coords = onGrid col cursor.row

        (newTime, col) = lookup time cursor.timeMap

    in
    ( newTime
    , coords
    )


renderTransition now (first, second) cursor =
    let 
        (newTimemap, start) =
            position 
                (Timeline.endTime first)
                cursor

        (finalTimemap, end) =
            position 
                (Timeline.startTime second)
                { cursor | timeMap = newTimemap }
    in
    { row = cursor.row
    , timeMap = finalTimemap
    , rendered = 
        line Faded start end
            :: cursor.rendered
    }


renderEvent now event cursor =
    let 
        (newTimemap, start) =
            position 
                (Timeline.startTime event)
                cursor

        (finalTimemap, end) =
            position 
                (Timeline.endTime event)
                { cursor | timeMap = newTimemap }



    in
    if (Timeline.startTime event) == (Timeline.endTime event) then
        { row = cursor.row
        , timeMap = finalTimemap
        , rendered = 
           dot Faded end
                :: cursor.rendered
        }

    else
        { row = cursor.row
        , timeMap = finalTimemap
        , rendered = 
            dot Faded start
                :: dot Faded end
                :: line Faded start end
                :: cursor.rendered
        }



dot : Style -> Interpolate.Point -> Svg.Svg Msg
dot style point =
    Svg.circle
        [ SvgA.cx (String.fromFloat point.x)
        , SvgA.cy (String.fromFloat point.y)
        , SvgA.r "8"
        , SvgA.fill 
            (case style of
                Normal ->
                    "black"
                Highlight ->
                    "red"
                Faded ->
                    "white"
            )
     , SvgA.stroke 
        (case style of
            Normal ->
                 "black"
            Highlight ->
                "black"
            Faded ->
                "black"

        )
    , SvgA.strokeDasharray 
        (case style of
            Normal ->
                "none"
            
            Highlight ->
                "none"
            
            Faded ->
                "none"

        )
    , SvgA.strokeWidth "3"
    ]
    []

line : Style -> Interpolate.Point -> Interpolate.Point -> Svg.Svg Msg
line style one two =
    Svg.line
        [ SvgA.x1 (String.fromFloat one.x)
        , SvgA.y1 (String.fromFloat one.y)
        , SvgA.x2 (String.fromFloat two.x)
        , SvgA.y2 (String.fromFloat two.y)
        , SvgA.stroke 
            (case style of
                Normal ->
                    "black"
                Highlight ->
                    "red"
                Faded ->
                    "black"

            )
        , SvgA.strokeDasharray 
            (case style of
                Normal ->
                    "none"
                
                Highlight ->
                    "none"
                
                Faded ->
                    "5,5"
            )
        , SvgA.strokeWidth "3"
        ]
        []




curve : Style -> Interpolate.Point -> Interpolate.Point -> Interpolate.Point -> Interpolate.Point -> Svg.Svg Msg
curve style c0 c1 c2 c3 =
    Svg.path
        [ SvgA.d 
            (String.join " "
                [ "M "
                ++ renderPoint c0
                ++ " C "
                    ++ renderPoint c1
                    ++ ", "
                    ++ renderPoint c2
                    ++ ", "
                    ++ renderPoint c3
                ]

            )
        , SvgA.strokeWidth "3"
        , SvgA.stroke 
            (case style of
                Normal ->
                    "black"
                Highlight ->
                    "red"
                Faded ->
                    "black"

            )
        , SvgA.strokeDasharray 
            (case style of
                Normal ->
                    "none"
                
                Highlight ->
                    "none"
                
                Faded ->
                    "5,5"
            )
        , SvgA.fill "rgba(0,0,0,0)"
        ]
        []

renderBezierString segments str =
    case segments of
        [] ->
            str

        segment :: remaining ->
            renderBezierString remaining
                (str
                    ++ " C "
                    ++ renderPoint segment.oneControl
                    ++ " "
                    ++ renderPoint segment.twoControl
                    ++ " "
                    ++ renderPoint segment.two
                )


renderPoint : Interpolate.Point -> String
renderPoint p =
    String.fromFloat p.x ++ " " ++ String.fromFloat p.y

