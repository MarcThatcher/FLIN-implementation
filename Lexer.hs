--{-# LANGUAGE FlexibleContexts #-}

module Lexer where

import Control.Monad      (guard)
import Data.Char          (isAlphaNum, isLower, isUpper)
import Text.Parsec
import Text.Parsec.String (Parser)

-- ----------------------------------------------------------------
-- Tokens
-- ----------------------------------------------------------------
data Token
    = TEquals             -- '='
    | TTilde              -- '~'
    | TLet                -- 'let'
    | TIn                 -- 'in'
    | TLowerID String
    | TUpperID String
    | TOpenParen          -- '('
    | TCloseParen         -- ')'
    | TOpenSqParen        -- '['
    | TCloseSqParen       -- ']'
    | TCons               -- ':'
    | TComma              -- ','
    | TPar                -- '|'
    | TBlank              -- '-'
    | TStar               -- '*' generic constructor
    | TNat Int            -- natural number literal
    | TIntVar String      -- '_x' natural number variable
    | THat                -- '^' for HOFs ; deprecated
    | TLam                -- '\' (lambda) for HOFs
    | THash               -- '#' for built-in arithmetic and (in)equality functions
    | TQuestion           -- '?'for conditionals
    | TLess               -- '<'
    | TGreater            -- '>'
    | TEqualEqual         -- '=='
    | TNotEqual           -- '!='
    | TCaseArrow          -- '=>'
    | TWildCard           -- '_' for conditionals
    deriving (Eq, Show)

-- ----------------------------------------------------------------
-- Lexer
-- ----------------------------------------------------------------
lexToken :: Parser Token
lexToken = choice
  [ reservedLet
  , reservedIn
  , try (string "==" >> pure TEqualEqual)
  , try (string "!=" >> pure TNotEqual)
  , try (string "=>" >> pure TCaseArrow)
  , symbol '='  >> pure TEquals
  , symbol '~'  >> pure TTilde
  , symbol '('  >> pure TOpenParen
  , symbol ')'  >> pure TCloseParen
  , symbol '['  >> pure TOpenSqParen
  , symbol ']'  >> pure TCloseSqParen
  , symbol ','  >> pure TComma
  , symbol '|'  >> pure TPar
  , natVarIdent
  , wildcard
  , symbol '-'  >> pure TBlank
  , symbol ':'  >> pure TCons
  , symbol '*'  >> pure TStar
  , symbol '^'  >> pure THat
  , symbol '@' >> pure (TLowerID "i_app")
  , symbol '\\' >> pure TLam
  , symbol '#' >> pure THash
  , symbol '?' >> pure TQuestion
  , symbol '<' >> pure TLess
  , symbol '>' >> pure TGreater
  , natural
  , lowerIdent
  , upperIdent
  ] <?> "token"

-- ----------------------------------------------------------------
-- Pieces
-- ----------------------------------------------------------------
reservedIn :: Parser Token
reservedIn = try $ do
  _ <- string "in"
  notFollowedBy (satisfy isIdentChar)
  pure TIn

reservedLet :: Parser Token
reservedLet = try $ do
  _ <- string "let"
  notFollowedBy (satisfy isIdentChar)
  pure TLet

natural :: Parser Token
natural = TNat . read <$> many1 digit

natVarIdent :: Parser Token
natVarIdent = try $ do
  _  <- symbol '_'
  x  <- satisfy isLower
  xs <- many (satisfy isIdentChar)
  pure (TIntVar (x:xs))

wildcard :: Parser Token
wildcard = symbol '_' >> pure TWildCard

lowerIdent :: Parser Token
lowerIdent = try $ do
  x  <- satisfy isLower
  xs <- many (satisfy isIdentChar)
  let s = x:xs
  guard (s /= "let" && s /= "in")  -- exclude both reserved words
  pure (TLowerID s)

upperIdent :: Parser Token
upperIdent = do
  x  <- satisfy isUpper
  xs <- many (satisfy isIdentChar)
  pure (TUpperID (x:xs))

isIdentChar :: Char -> Bool
isIdentChar c = isAlphaNum c || c == '_' || c == '\''

symbol :: Char -> Parser Char
symbol = char

ws :: Parser ()
ws = skipMany (oneOf " \t\r\n")

-- ----------------------------------------------------------------
-- add () to nullary constructors 
-- ----------------------------------------------------------------
fixConstructors :: [Token] -> [Token]
fixConstructors [] = []
fixConstructors (TUpperID s : rest) =
  case rest of
    (TOpenParen : _) -> TUpperID s : fixConstructors rest
    _                -> TUpperID s : TOpenParen : TCloseParen : fixConstructors rest
fixConstructors (t : ts) = t : fixConstructors ts


-- ----------------------------------------------------------------
-- API
-- ----------------------------------------------------------------
lexer :: String -> Either ParseError [Token]
lexer input = case parse (ws *> many (lexToken <* ws) <* eof) "<lexer>" input of
    Left err   -> Left err
    Right toks -> Right (fixConstructors toks)