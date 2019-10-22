{-|
Module      : Parser.Monad
Description : All monadic operations for the parser.
License     : BSD 3-Clause "New" or "Revised" License
Maintainer  : gustavoaca1997@outlook.com, dave00dark@gmail.com
Stability   : experimental

Here is a longer description of this module, containing some
commentary with @some markup@.
-}

module Parser.Monad where

import qualified Semantic.Data as Sem
import qualified Control.Monad.RWS.Lazy as RWS
import qualified Data.Set as Set
import qualified Data.Map.Lazy as Map
import Tokens


-- | State of the parser
type ParserState = (Sem.ScopeSet, Sem.SymbolTable, Int)

-- | Monad of the parser
type ParserMonad = RWS.RWST String () ParserState IO

-- | Initial state with the level pervasive.
initialState :: ParserState
initialState = (Set.singleton 0, initialMap, 1)
    where 
        wholeEntry          =    ("whole",      [Sem.Entry "whole"      Sem.Type        0 Nothing Nothing])
        halfEntry           =    ("half",       [Sem.Entry "half"       Sem.Type        0 Nothing Nothing])
        quarterEntry        =    ("quarter",    [Sem.Entry "quarter"    Sem.Type        0 Nothing Nothing])
        eightEntry          =    ("eight",      [Sem.Entry "eight"      Sem.Type        0 Nothing Nothing])
        thirySecondEntry    =    ("32th",       [Sem.Entry "32th"       Sem.Type        0 Nothing Nothing])
        sixtyFourthEntry    =    ("64th",       [Sem.Entry "64th"       Sem.Type        0 Nothing Nothing])
        melodyEntry         =    ("Melody",     [Sem.Entry "Melody"     Sem.Constructor 0 Nothing Nothing])
        sampleEntry         =    ("Sample",     [Sem.Entry "Sample"     Sem.Constructor 0 Nothing Nothing])
        initialMap          =    Map.fromList [wholeEntry, halfEntry, quarterEntry, eightEntry, thirysecondEntry, float64Entry, arrayEntry, pointerEntry]

-- | Insert a new entry into the SymbolTable
insertEntry :: Sem.Entry -> ParserMonad ()
insertEntry entry = do
    (scopeSet, table, lvl) <- RWS.get
    let table' = Map.insertWith (++) (Sem.entry_name entry) [entry] table
    RWS.put (scopeSet, table', lvl)

-- | Insert a new scope/level into the set of scopeSet
insertScope :: Int -> ParserMonad ()
insertScope newScope = do
    (scopeSet, table, lvl) <- RWS.get
    let scopeSet' = Set.insert newScope scopeSet
    RWS.put (scopeSet', table, lvl)

-- | Delete a scope from the set of scopeSet
deleteScope :: Int -> ParserMonad ()
deleteScope scope = do
    (scopeSet, table, lvl) <- RWS.get
    let scopeSet' = Set.delete scope scopeSet
    RWS.put (scopeSet', table, lvl)

-- | Get chain from a symbol
getChain :: String -> ParserMonad (Maybe [Sem.Entry])
getChain symbol = do
    (_, table, _) <- RWS.get
    -- Get chain of matching entries
    return $ Map.lookup symbol table

-- | Look for a symbol in the symbol table and return its scope
lookup :: String -> ParserMonad (Maybe Sem.Entry)
lookup symbol = do
    (scopeSet, _, _) <- RWS.get
    chainMaybe <- getChain symbol
    case chainMaybe of
        Nothing     -> return Nothing
        Just chain  ->
            -- Get entries that their scope is active
            case filter (\e -> Set.member (Sem.entry_scope e) scopeSet) chain of
                [] -> return Nothing
                entries -> do
                    -- Return entry with maximum scope
                    let getBest e1 e2 = if Sem.entry_scope e1 > Sem.entry_scope e2 then e1 else e2
                    return $ Just $ foldl1 getBest entries

-- | Find if a symbol is in the scope given. This is mainly
--  used for looking fields up.    
lookupField :: String -> Int -> ParserMonad (Maybe Sem.Entry)
lookupField symbol level = do
    chainMaybe <- getChain symbol
    case chainMaybe of
        Nothing     -> return Nothing
        Just chain  ->
            -- Get entry that matches symbol
            case filter (\e -> Sem.entry_scope e == level) chain of
                [] -> return Nothing
                [e] -> return $ Just e
                _ -> return Nothing

-- | Increment level of scope
incrementScope :: ParserMonad ()
incrementScope = do
    (scopeSet, table, lvl) <- RWS.get
    RWS.put (scopeSet, table, lvl+1)