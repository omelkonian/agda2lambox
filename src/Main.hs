{-# LANGUAGE DeriveGeneric, DeriveAnyClass, OverloadedStrings #-}

module Main where

import Control.Monad ( unless )
import Control.Monad.IO.Class ( MonadIO(liftIO) )
import Control.DeepSeq ( NFData(..) )
import Data.IORef ( IORef, newIORef, readIORef, modifyIORef' )
import Data.Maybe ( fromMaybe, catMaybes, isJust, isNothing )
import Data.Version ( showVersion )
import GHC.Generics ( Generic )
import System.Console.GetOpt ( OptDescr(Option), ArgDescr(ReqArg) )
import System.Directory ( createDirectoryIfMissing )
import System.FilePath ( (</>) )

import Paths_agda2lambox ( version )

import Agda.Lib hiding ( (<?>), pretty )
import Agda.Syntax.Common.Pretty ( (<?>), pretty )
import Agda.Utils ( pp, unqual, hasPragma )

import Agda2Lambox.Convert ( convert )
import Agda2Lambox.Convert.Function ( convertFunction )
import Agda2Lambox.Convert.Data     ( convertDatatype )
import Agda2Lambox.Convert.Record   ( convertRecord   )
import Agda2Lambox.Monad ( runC0, inMutuals )
import CoqGen ( ToCoq(ToCoq) )
import LambdaBox ( KerName, GlobalDecl, qnameToKerName, CoqModule(CoqModule) )


main :: IO ()
main = runAgda [Backend backend]

-- | LambdaBox backend options.
data Options = Options { optOutDir :: Maybe FilePath }
  deriving (Generic, NFData)

-- | Setter for backend output directory option.
outdirOpt :: Monad m => FilePath -> Options -> m Options
outdirOpt dir opts = return opts { optOutDir = Just dir }

defaultOptions :: Options
defaultOptions = Options { optOutDir = Nothing }


data ModuleEnv = ModuleEnv 
  { modProgs :: IORef [KerName]
     -- ^ Names of programs to evaluate in a module
  }

type ModuleRes = ()

backend :: Backend' Options Options ModuleEnv ModuleRes (Maybe (KerName, GlobalDecl))
backend = Backend'
  { backendName           = "agda2lambox"
  , backendVersion        = Just (showVersion version)
  , options               = defaultOptions
  , commandLineFlags      =
      [ Option ['o'] ["out-dir"] (ReqArg outdirOpt "DIR")
        "Write output files to DIR. (default: project root)"
      ]
  , isEnabled             = \ _ -> True
  , preCompile            = return
  , postCompile           = \ _ _ _ -> return ()
  , preModule             = moduleSetup
  , postModule            = writeModule
  , compileDef            = compile
  , scopeCheckingSuffices = False
  , mayEraseType          = \ _ -> return True
  }


moduleSetup :: Options -> IsMain -> TopLevelModuleName -> Maybe FilePath
            -> TCM (Recompile ModuleEnv ModuleRes)
moduleSetup _ _ m _ = do
  setScope . iInsideScope =<< curIF
  Recompile . ModuleEnv <$> liftIO (newIORef [])


compile :: Options -> ModuleEnv -> IsMain -> Definition -> TCM (Maybe (KerName, GlobalDecl))
compile opts menv _ def@Defn{..} =
  fmap (qnameToKerName defName,) <$> -- prepend kername
    case theDef of

      Function{} -> do
          -- if the function is annotated with a COMPILE pragma
          -- then it is added to the list of programs to run
          whenM (hasPragma defName) $ 
            liftIO $ modifyIORef' (modProgs menv) (qnameToKerName defName:)

          runC0 (convertFunction def)

      Datatype{} -> runC0 (convertDatatype def)

      Record{}   -> Just <$> runC0 (convertRecord def)

      _          -> Nothing <$ (liftIO $ putStrLn $ "Skipping " <> prettyShow defName)


writeModule :: Options -> ModuleEnv -> IsMain -> TopLevelModuleName
            -> [Maybe (KerName, GlobalDecl)]
            -> TCM ModuleRes
writeModule opts menv _ m (reverse . catMaybes -> cdefs) = do
  progs   <- liftIO $ readIORef $ modProgs menv
  compDir <- compileDir

  let outDir   = fromMaybe compDir (optOutDir opts)
      fileName = (outDir </>) . moduleNameToFileName m

  liftIO $ createDirectoryIfMissing True outDir

  let mod = CoqModule cdefs progs

  unless (null cdefs) $ liftIO do
    putStrLn $ "Writing " <> fileName ".{v,txt}"

    writeFile (fileName ".txt")
      $ (<> "\n")
      $ pp $ mod

    writeFile (fileName ".v")
      $ (<> "\n")
      $ pp $ ToCoq $ mod
