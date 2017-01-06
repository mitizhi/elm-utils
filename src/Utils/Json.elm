module Utils.Json exposing (..)

{-|
    Utility JSON functions.

@docs (///), (<||), decConvertDict, decDict, encDict, encMaybe
-}

import Dict exposing (..)
import Json.Decode as JD exposing (..)
import Json.Encode as JE exposing (..)
import Utils.Ops exposing (..)
import Utils.Tuple exposing (..)


{-|
    Operator to allow stringing decoders together to construct a record via its constructor.

    Usage:

    type alias User =
        { name : String
        , age : Int
        , amount : Float
        , twelve : Int
        , address : Address
        }

    userDecoder : Json.Decoder User
    userDecoder =
        Json.succeed User
            <|| ("name" := string)
            <|| ("age" := int)
            <|| ("amount" := float)
            <|| Json.succeed 12
            <|| ("address" := addressDecoder)
-}
(<||) : JD.Decoder (a -> b) -> JD.Decoder a -> JD.Decoder b
(<||) =
    JD.object2 (<|)


{-|
    Operator to provide a default for a Decoder.

    Usage:

    type alias User =
        { name : String
        , age : Int
        , amount : Float
        , twelve : Int
        , address : Address
        }

    userDecoder : Json.Decoder User
    userDecoder =
        Json.succeed User
            <|| ("name" := string)
            <|| ("age" := int)
            <|| (("amount" := float) /// 100)
            <|| Json.succeed 12
            <|| ("address" := addressDecoder)
-}
(///) : JD.Decoder a -> a -> JD.Decoder a
(///) decoder default =
    (maybe decoder) `JD.andThen` (\maybe -> JD.succeed (maybe ?= default))


{-|
    Convenience function for encoding a Maybe with a encoder and NULL default.

    Usage:

    import Json.Encode as JE exposing (..)

    JE.encode 0 <|
        JE.object
            [ ( "street", Json.encMaybe JE.string address.street )
            , ( "city", Json.encMaybe JE.string address.city )
            , ( "state", Json.encMaybe JE.string address.state )
            , ( "zip", Json.encMaybe JE.string address.zip )
            ]

-}
encMaybe : (a -> JE.Value) -> Maybe a -> JE.Value
encMaybe encoder maybe =
    maybe |?> (\just -> encoder just) ?= JE.null


{-|
    Convenience function for encoding a Dictionary to a JS object of the following form:

    {
        keys: [
            // keys encoded here
        ],
        values: [
            // values encoded here
        ]
    }

    Usage:

    import Json.Encode as JE exposing (..)

    type alias Model =
        { ids : Dict Int (Set String)
        , ages : Dict String Int
        }

    JE.encode 0 <|
        JE.object
            [ ( "ids", Json.encDict JE.int (JE.list << List.map JE.string << Set.toList) model.ids )
            , ( "ages", Json.encDict JE.string JE.int model.ages )
            ]

-}
encDict : (comparable -> JE.Value) -> (value -> JE.Value) -> Dict comparable value -> JE.Value
encDict keyEncoder valueEncoder dict =
    JE.object
        [ ( "keys", JE.list <| List.map keyEncoder <| Dict.keys dict )
        , ( "values", JE.list <| List.map valueEncoder <| Dict.values dict )
        ]


{-|
    Convenience function for decoding a Dictionary WITH a value converstion function from a JS object of the following form:

    {
        keys: [
            // keys encoded here
        ],
        values: [
            // values encoded here
        ]
    }

    Usage:

    import Json.Decode as JD exposing (..)

    type alias Model =
        { ids : Dict Int (Set String)
        , ages : Dict String Int
        }

    -- here json is a JSON string that was generated by encDict
    JD.decodeString
        ((JD.succeed Model)
            <|| ("ids" := Json.decConvertDict Set.fromList JD.int (JD.list JD.string))
            <|| ("ages" := Json.decDict JD.string JD.int)
        )
        json

-}
decConvertDict : (a -> value) -> Decoder comparable -> Decoder a -> Decoder (Dict comparable value)
decConvertDict valuesConverter keyDecoder valueDecoder =
    let
        makeDict keys values =
            Dict.fromList <| secondMap valuesConverter <| List.map2 (,) keys values
    in
        JD.object2 makeDict ("keys" := JD.list keyDecoder) ("values" := JD.list valueDecoder)


{-|
    Convenience function for decoding a Dictionary WITHOUT a value conversion function from a JS object of the following form:

    {
        keys: [
            // keys encoded here
        ],
        values: [
            // values encoded here
        ]
    }

    Usage:

    import Json.Decode as JD exposing (..)

    type alias Model =
        { ids : Dict Int (Set String)
        , ages : Dict String Int
        }

    -- here json is a JSON string that was generated by encDict
    JD.decodeString
        ((JD.succeed Model)
            <|| ("ids" := Json.decConvertDict Set.fromList JD.int (JD.list JD.string))
            <|| ("ages" := Json.decDict JD.string JD.int)
        )
        json
-}
decDict : Decoder comparable -> Decoder value -> Decoder (Dict comparable value)
decDict =
    decConvertDict identity
