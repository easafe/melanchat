module  Server.Settings.Handler where

import Prelude
import Server.Types
import Shared.Types

import Payload.ResponseTypes (Response)
import Run as R
import Server.Logout as SL
import Server.Settings.Action as SSA
import Server.Settings.Template as SST

settings :: { guards :: { loggedUserID :: PrimaryKey } } -> ServerEffect String
settings { guards: { loggedUserID } } = R.liftEffect SST.template

accountEmail :: { guards :: { loggedUserID :: PrimaryKey }, body :: { email :: String} } -> ServerEffect (Response Ok)
accountEmail { guards: { loggedUserID }, body: { email } } = do
      SSA.changeEmail loggedUserID email
      pure SL.expireCookies

accountPassword :: { guards :: { loggedUserID :: PrimaryKey }, body :: { password:: String } } -> ServerEffect (Response Ok)
accountPassword { guards: { loggedUserID }, body : { password } } = do
      SSA.changePassword loggedUserID password
      pure SL.expireCookies

accountTerminate :: forall r. { guards :: { loggedUserID :: PrimaryKey } | r } -> ServerEffect (Response Ok)
accountTerminate { guards: { loggedUserID } } = do
      SSA.terminateAccount loggedUserID
      pure SL.expireCookies

