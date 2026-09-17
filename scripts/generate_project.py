#!/usr/bin/env python3
"""Dependency-free, deterministic Xcode project generation."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
objects={}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name,body): objects[uid(name)]=body;return uid(name)
def arr(items):return '('+','.join(items)+',)'
sources=sorted((root/'PocketBonham').rglob('*.swift'))
refs=[];builds=[]
for path in sources:
    rel=str(path.relative_to(root));ref=add(rel,'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "'+rel+'"; sourceTree = SOURCE_ROOT;');refs.append(ref)
    builds.append(add('build '+rel,'isa = PBXBuildFile; fileRef = '+ref+';'))
kit=add('kits','isa = PBXFileReference; lastKnownFileType = folder; path = PocketBonham/Resources/Kits; sourceTree = SOURCE_ROOT;');refs.append(kit)
kitbuild=add('kitbuild','isa = PBXBuildFile; fileRef = '+kit+';')
assets=add('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = PocketBonham/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;');refs.append(assets)
assetbuild=add('assetbuild','isa = PBXBuildFile; fileRef = '+assets+';')
app=add('app','isa = PBXFileReference; explicitFileType = wrapper.application; path = PocketBonham.app; sourceTree = BUILT_PRODUCTS_DIR;')
testfile=add('uitestfile','isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = PocketBonhamUITests/PocketBonhamUITests.swift; sourceTree = SOURCE_ROOT;');refs.append(testfile)
testbuild=add('uitestbuild','isa = PBXBuildFile; fileRef = '+testfile+';')
testproduct=add('uitestproduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = PocketBonhamUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products=add('products','isa = PBXGroup; children = '+arr([app,testproduct])+'; name = Products; sourceTree = "<group>";')
group=add('group','isa = PBXGroup; children = '+arr(refs+[products])+'; sourceTree = "<group>";')
package=add('package','isa = XCLocalSwiftPackageReference; relativePath = .;')
packages=[];frameworks=[]
for name in ['BonhamCore','BonhamRender']:
    ref=add('package '+name,'isa = XCSwiftPackageProductDependency; productName = '+name+';');packages.append(ref)
    frameworks.append(add('link '+name,'isa = PBXBuildFile; productRef = '+ref+';'))
sourcephase=add('sources','isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+arr(builds)+'; runOnlyForDeploymentPostprocessing = 0;')
resourcephase=add('resources','isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = '+arr([kitbuild,assetbuild])+'; runOnlyForDeploymentPostprocessing = 0;')
frameworkphase=add('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = '+arr(frameworks)+'; runOnlyForDeploymentPostprocessing = 0;')
configs={}
for target in ['project','app','test']:
    cs=[]
    for config in ['Debug','Release']:
        settings={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'18.0','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','DEBUG_INFORMATION_FORMAT':'dwarf' if config=='Debug' else '"dwarf-with-dsym"','SWIFT_OPTIMIZATION_LEVEL':'"-Onone"' if config=='Debug' else '"-O"','ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO'}
        if target in ['app','test']:
            settings.update({'PRODUCT_NAME':'"$(TARGET_NAME)"','PRODUCT_BUNDLE_IDENTIFIER':'com.mkodi.PocketBonham'+('.UITests' if target=='test' else ''),'GENERATE_INFOPLIST_FILE':'YES','CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'1','SUPPORTED_PLATFORMS':'"iphoneos iphonesimulator"','SWIFT_EMIT_LOC_STRINGS':'YES'})
        if target=='app':settings.update({'INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait','INFOPLIST_KEY_CFBundleDisplayName':'PocketBonham','MARKETING_VERSION':'1.0','CURRENT_PROJECT_VERSION':'1','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon'})
        if target=='test':settings.update({'TEST_TARGET_NAME':'PocketBonham'})
        if config=='Debug':
            settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
            settings['ONLY_ACTIVE_ARCH']='YES'
        cs.append(add(target+config,'isa = XCBuildConfiguration; name = '+config+'; buildSettings = {'+' '.join(k+' = '+v+';' for k,v in settings.items())+'};'))
    configs[target]=add(target+'configs','isa = XCConfigurationList; buildConfigurations = '+arr(cs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
appTarget=add('appTarget','isa = PBXNativeTarget; buildConfigurationList = '+configs['app']+'; buildPhases = '+arr([sourcephase,frameworkphase,resourcephase])+'; buildRules = (); dependencies = (); name = PocketBonham; packageProductDependencies = '+arr(packages)+'; productName = PocketBonham; productReference = '+app+'; productType = "com.apple.product-type.application";')
proxy=add('proxy','isa = PBXContainerItemProxy; containerPortal = '+uid('project')+'; proxyType = 1; remoteGlobalIDString = '+appTarget+'; remoteInfo = PocketBonham;')
dep=add('dep','isa = PBXTargetDependency; target = '+appTarget+'; targetProxy = '+proxy+';')
testsources=add('testsources','isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = '+arr([testbuild])+'; runOnlyForDeploymentPostprocessing = 0;')
testTarget=add('testTarget','isa = PBXNativeTarget; buildConfigurationList = '+configs['test']+'; buildPhases = '+arr([testsources])+'; buildRules = (); dependencies = '+arr([dep])+'; name = PocketBonhamUITests; productName = PocketBonhamUITests; productReference = '+testproduct+'; productType = "com.apple.product-type.bundle.ui-testing";')
project=add('project','isa = PBXProject; attributes = {BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2630;}; buildConfigurationList = '+configs['project']+'; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base); mainGroup = '+group+'; productRefGroup = '+products+'; projectDirPath = ""; projectRoot = ""; packageReferences = '+arr([package])+'; targets = '+arr([appTarget,testTarget])+';')
folder=root/'PocketBonham.xcodeproj';folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(key+' = {'+body+'};\n' for key,body in objects.items())+'}; rootObject = '+project+'; }\n')
schemes=folder/'xcshareddata/xcschemes';schemes.mkdir(parents=True,exist_ok=True)
def ref(id,name):return '<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="'+id+'" BuildableName="'+name+'" BlueprintName="'+name.split('.')[0]+'" ReferencedContainer="container:PocketBonham.xcodeproj"/>'
(schemes/'PocketBonham.xcscheme').write_text('<?xml version="1.0" encoding="UTF-8"?><Scheme LastUpgradeVersion="2630" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">'+ref(appTarget,'PocketBonham.app')+'</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">'+ref(testTarget,'PocketBonhamUITests.xctest')+'</TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref(appTarget,'PocketBonham.app')+'</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">'+ref(appTarget,'PocketBonham.app')+'</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>')
print(folder)
