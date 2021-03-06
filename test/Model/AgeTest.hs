{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}
module Model.AgeTest where

import Data.Aeson
import Data.Time
import Test.Tasty.HUnit

import Model.Age
import Model.TypeOrphans ()

unit_age_toJSON :: Assertion
unit_age_toJSON =
    encode (Age 10) @?= "10"

-- possible property:
  -- d + ageTime(age d (d2)) = d2

unit_age :: Assertion
unit_age = do
    -- example
    age (jan2000day 1) (jan2000day 3) @?= Age 2
    -- edge cases
    age (jan2000day 10) (jan2000day 3) @?= Age (-7) -- should return nothing instead
    age (jan2000day 1) (jan2000day 1) @?= Age 0

type DayOfMonth = Int

jan2000day :: DayOfMonth -> Day
jan2000day = fromGregorian 2000 1

unit_yearsAge :: Assertion
unit_yearsAge =
    -- example
    yearsAge (1 :: Double) @?= Age 366

unit_ageTime :: Assertion
unit_ageTime =
    ageTime (Age 1) @?= 60*60*24
