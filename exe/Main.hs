{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Main ( main ) where

import           Control.Monad
import           Data.Aeson                    hiding (json)
import qualified Data.ByteString.Lazy          as BL
import           Data.Maybe
import           Options.Generic
import           Text.ParserCombinators.Parsec
import           Text.Show.Pretty

import           Regex

-- | Example `./regex-fsm --regex (a|b)|(a|b) --inputLength 5 --verbose True
data Options
  = Options
  { regex :: String
  , inputLength :: Int
  , verbose :: Maybe Bool
  , output :: String
  , chunks :: Maybe Int
  } deriving (Show, Eq, Generic)

modifiers :: Modifiers
modifiers = defaultModifiers { shortNameModifier = firstLetter }

instance ParseRecord Options where
  parseRecord = parseRecordWithModifiers modifiers

-- | Main function
main :: IO ()
main = do
  Options {..} <- getRecord "regex-fsm"
  case parseRegex regex :: Either ParseError (Reg Char) of
    Left err -> do
      error $ "Failed to parse, error: " ++ show err
    Right regex' -> do
      let thompson  = thompsons regex'
          closure   = getClosure thompson
          subset'   = subset thompson
          minimized = minimize subset'
          matrices  = premultiply (fromMaybe 1 chunks) $ toMatrices inputLength minimized
      BL.writeFile output $ encode (Matrices inputLength matrices)
      when (verbose == Just True) $ do
        putStrLn "== Regular Expression AST =="
        pPrint regex'
        putStrLn "== Thompson's construction =="
        pPrint (thompson :: ENFA Int Char)
        putStrLn "== Closure construction =="
        pPrint closure
        putStrLn "== Subset construction =="
        pPrint subset'
        putStrLn "== Minimized DFA =="
        pPrint minimized
        putStrLn "== Matrix Branching Program =="
        pPrint matrices
