module Server.Database.User  where

import Server.Types
import Shared.Types
import Prelude
import Droplet.Language
import Data.Maybe (Maybe)

import Server.Database as SD

type Users = (
      id :: Auto Int,
      name :: String,
      headline :: String,
      joined :: Default DateTime,
      email :: String,
      birthday :: Maybe Date,
      description :: String,
      avatar :: Maybe String,
      gender :: Gender,
      country :: Int
      active :: Default Boolean
)

users :: Table "users" Users
users = Table

_id :: Proxy "id"
_id = Proxy

_name :: Proxy "name"
_name = Proxy

_headline :: Proxy "headline"
_headline = Proxy

_joined :: Proxy "joined"
_joined = Proxy

_email :: Proxy "email"
_email = Proxy

_birthday :: Proxy "birthday"
_birthday = Proxy

_description :: Proxy "description"
_description = Proxy

_avatar :: Proxy "avatar"
_avatar = Proxy

_gender :: Proxy "gender"
_gender = Proxy

_country :: Proxy "country"
_country = Proxy

_active :: Proxy "active"
_active = Proxy

baseQuery :: String
baseQuery = "select id, email, password from users where active and "

userBy :: By -> ServerEffect (Maybe RegisterLoginUser)
userBy = case _ of
      Email value -> SD.single (baseQuery <> "lower(email) = lower($1)") $ Row1 value
      ID value -> SD.single (baseQuery <> "id = $1") $ Row1 value

