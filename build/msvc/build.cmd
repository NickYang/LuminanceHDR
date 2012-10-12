@echo off
SETLOCAL

devenv /? > NUL
IF ERRORLEVEL 1 (
	echo.
	echo.ERROR: This file must be run inside a VS command prompt!
	echo.
	goto error_end
)

IF EXIST ..\msvc (
	echo.
	echo.ERROR: This file should NOT be executed within the LuminanceHDR source directory,
	echo.       but in a new empty folder!
	echo.
	goto error_end
)

ml64.exe > NUL
IF ERRORLEVEL 1 (
	set Platform=Win32
	set RawPlatform=x86
	set CpuPlatform=ia32
) ELSE (
	set Platform=x64
	set RawPlatform=x64
	set CpuPlatform=intel64
)

SET VISUAL_STUDIO_VC_REDIST=%VCINSTALLDIR%\redist\%RawPlatform%

IF DEFINED VS110COMNTOOLS (
	REM Visual Studio 2012
	set VS_SHORT=vc11
	set VS_CMAKE=Visual Studio 11
	set VS_PROG_FILES=Microsoft Visual Studio 11.0
	
) ELSE IF DEFINED VS100COMNTOOLS (
	REM Visual Studio 2010
	set VS_SHORT=vc10
	set VS_CMAKE=Visual Studio 10
	set VS_PROG_FILES=Microsoft Visual Studio 10.0
	
) ELSE (
	REM Visual Studio 2008
	set VS_SHORT=vc9
	set VS_CMAKE=Visual Studio 9 2008
	set VS_PROG_FILES=Microsoft Visual Studio 9.0
)
IF %Platform% EQU x64 (
	set VS_CMAKE=%VS_CMAKE% Win64
)

call setenv.cmd

IF NOT EXIST %CMAKE_DIR%\bin\cmake.exe (
	echo.
	echo.ERROR: CMake not found: %CMAKE_DIR%\bin\cmake.exe
	echo.
	goto error_end
)

IF NOT EXIST %CYGWIN_DIR%\bin\cp.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\cvs.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\git.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\gzip.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\mv.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\nasm.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\sed.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\ssh.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\svn.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\tar.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\unzip.exe GOTO cygwin_error
IF NOT EXIST %CYGWIN_DIR%\bin\wget.exe GOTO cygwin_error
GOTO cygwin_ok

:cygwin_error
echo ERROR: Cygwin with 
echo    cp
echo    cvs
echo    git 
echo    gzip 
echo    mv
echo    nasm
echo    sed 
echo    ssh 
echo    svn 
echo    tar 
echo    unzip 
echo    wget
echo is required
GOTO error_end

:cygwin_ok


IF NOT DEFINED Configuration (
	set Configuration=Release
)

cls
echo.
echo.--- %VS_CMAKE% ---
echo.Configuration = %Configuration%
echo.Platform = %Platform% (%RawPlatform%)
echo.

IF NOT EXIST %TEMP_DIR% (
	mkdir %TEMP_DIR%
)


IF NOT EXIST vcDlls (
	mkdir vcDlls
	robocopy "%vcinstalldir%redist\%RawPlatform%" vcDlls /MIR >nul
)

IF NOT EXIST vcDlls\selected (
	mkdir vcDlls\selected

	%CYGWIN_DIR%\bin\cp.exe vcDlls/**/vcomp* vcDlls/selected
	%CYGWIN_DIR%\bin\cp.exe vcDlls/**/msv* vcDlls/selected
)

IF NOT EXIST %TEMP_DIR%\align_image_stack_%RawPlatform%.exe (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/align_image_stack_%RawPlatform%.exe qtpfsgui.sourceforge.net/win/align_image_stack_%RawPlatform%.exe
)

IF NOT EXIST %TEMP_DIR%\zlib-aa566e.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/zlib-aa566e.zip --no-check-certificate http://github.com/madler/zlib/zipball/aa566e86c46d2264bf623e51f5840bde642548ad
)

IF NOT EXIST zlib-aa566e (
	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/zlib-aa566e.zip
	%CYGWIN_DIR%\bin\mv.exe madler-zlib-* zlib-aa566e
	
	REM zlib must be compiled in the source folder, else exiv2 compilation
	REM fails due to zconf.h rename/compile problems, due to cmake
	pushd zlib-aa566e
	%CMAKE_DIR%\bin\cmake.exe -G "%VS_CMAKE%"
	IF errorlevel 1 goto error_end
	devenv zlib.sln /build "%Configuration%|%Platform%" /Project zlib
	IF errorlevel 1 goto error_end
	popd
)

IF NOT EXIST %TEMP_DIR%\lpng1513.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/lpng1513.zip http://sourceforge.net/projects/libpng/files/libpng15/1.5.13/lpng1513.zip/download
)
IF NOT EXIST lpng1513 (
	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/lpng1513.zip
	pushd lpng1513
	%CMAKE_DIR%\bin\cmake.exe -G "%VS_CMAKE%" . -DZLIB_ROOT=..\zlib-aa566e;..\zlib-aa566e\%Configuration%
	IF errorlevel 1	goto error_end
	devenv libpng.sln /build "%Configuration%|%Platform%" /Project png15
	IF errorlevel 1	goto error_end
	popd
)

IF NOT EXIST %TEMP_DIR%\expat-2.1.0.tar (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/expat-2.1.0.tar.gz http://sourceforge.net/projects/expat/files/expat/2.1.0/expat-2.1.0.tar.gz/download
	%CYGWIN_DIR%\bin\gzip.exe -d %TEMP_DIR%/expat-2.1.0.tar.gz
)
IF NOT EXIST expat-2.1.0 (
	%CYGWIN_DIR%\bin\tar.exe -xf %TEMP_DIR%/expat-2.1.0.tar
    
    pushd expat-2.1.0
	%CMAKE_DIR%\bin\cmake.exe -G "%VS_CMAKE%"
	IF errorlevel 1 goto error_end
	devenv expat.sln /build "%Configuration%|%Platform%" /Project expat
	IF errorlevel 1 goto error_end
	popd
)

IF NOT EXIST exiv2-2895 (
	%CYGWIN_DIR%\bin\svn.exe co -r 2895 svn://dev.exiv2.org/svn/trunk exiv2-2895
    
    pushd exiv2-2895
	%CMAKE_DIR%\bin\cmake.exe -G "%VS_CMAKE%"  -DZLIB_ROOT=..\zlib-aa566e;..\zlib-aa566e\Release
	IF errorlevel 1 goto error_end
	devenv exiv2.sln /build "%Configuration%|%Platform%" /Project exiv2
	IF errorlevel 1 goto error_end
    copy bin\%Platform%\Dynamic\*.h include
	popd  
)

IF NOT EXIST libjpeg-turbo-867 (
    %CYGWIN_DIR%\bin\svn.exe co -r 867 svn://svn.code.sf.net/p/libjpeg-turbo/code/trunk libjpeg-turbo-867
    IF NOT EXIST libjpeg-turbo-867.build (
        mkdir libjpeg-turbo-867.build
    )
	pushd libjpeg-turbo-867.build
	%CMAKE_DIR%\bin\cmake.exe -DCMAKE_BUILD_TYPE=%Configuration% -DNASM="%CYGWIN_DIR%\bin\nasm.exe" ..\libjpeg-turbo-867
	IF errorlevel 1 goto error_end
	nmake
	IF errorlevel 1 goto error_end
    copy jconfig.h ..\libjpeg-turbo-867
	popd
)

IF NOT EXIST %TEMP_DIR%\lcms2-493aac.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/lcms2-493aac.zip --no-check-certificate https://github.com/mm2/Little-CMS/zipball/493aac084b7df46e24ec86ffb6395e5d11cddfba
)


IF NOT EXIST lcms2-493aac (
	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/lcms2-493aac.zip
	%CYGWIN_DIR%\bin\mv.exe mm2-Little-CMS-* lcms2-493aac
	
	pushd lcms2-493aac
	devenv Projects\VC2010\lcms2.sln /Upgrade
	devenv Projects\VC2010\lcms2.sln /build "%Configuration%|%Platform%"  /Project lcms2_DLL
	IF errorlevel 1	goto error_end
	popd
)

IF NOT EXIST %TEMP_DIR%\tiff-4.0.3.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/tiff-4.0.3.zip http://download.osgeo.org/libtiff/tiff-4.0.3.zip
)

IF NOT EXIST tiff-4.0.3 (
	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/tiff-4.0.3.zip

	echo.JPEG_SUPPORT=^1> tiff-4.0.3\qtpfsgui_commands.in
	echo.JPEGDIR=%CD%\libjpeg-turbo-867>> tiff-4.0.3\qtpfsgui_commands.in
	echo.JPEG_INCLUDE=-I%CD%\libjpeg-turbo-867>> tiff-4.0.3\qtpfsgui_commands.in
	echo.JPEG_LIB=%CD%\libjpeg-turbo-867.build\turbojpeg-static.lib>> tiff-4.0.3\qtpfsgui_commands.in
	echo.ZIP_SUPPORT=^1>> tiff-4.0.3\qtpfsgui_commands.in
	echo.ZLIBDIR=..\..\zlib-aa566e\%Configuration%>> tiff-4.0.3\qtpfsgui_commands.in
	echo.ZLIB_INCLUDE=-I..\..\zlib-aa566e>> tiff-4.0.3\qtpfsgui_commands.in
	echo.ZLIB_LIB=$^(ZLIBDIR^)\zlib.lib>> tiff-4.0.3\qtpfsgui_commands.in

	pushd tiff-4.0.3
	nmake /s /c /f Makefile.vc @qtpfsgui_commands.in
	IF errorlevel 1 goto error_end
	popd
)

IF NOT EXIST %TEMP_DIR%\LibRaw-5c9b4fb.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/LibRaw-5c9b4fb.zip --no-check-certificate https://github.com/LibRaw/LibRaw/zipball/5c9b4fb7b6149721cdf4f2099032ac8bdf0dd57c
)

IF NOT EXIST %TEMP_DIR%\LibRaw-demosaic-pack-GPL2-6f851ba.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/LibRaw-demosaic-pack-GPL2-6f851ba.zip --no-check-certificate https://github.com/LibRaw/LibRaw-demosaic-pack-GPL2/zipball/6f851babcec79e50506cdda2aa55a6b6daeada3e
)

IF NOT EXIST LibRaw-demosaic-pack-GPL2-6f851ba (
	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/LibRaw-demosaic-pack-GPL2-6f851ba.zip
	%CYGWIN_DIR%\bin\mv.exe LibRaw-LibRaw-* LibRaw-demosaic-pack-GPL2-6f851ba
)

IF NOT EXIST %TEMP_DIR%\LibRaw-demosaic-pack-GPL3-f089589.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/LibRaw-demosaic-pack-GPL3-f089589.zip --no-check-certificate https://github.com/LibRaw/LibRaw-demosaic-pack-GPL3/zipball/f0895891fdaa775255af02275fce426a5bf5c9fc
)

IF NOT EXIST LibRaw-demosaic-pack-GPL3-f089589 (
	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/LibRaw-demosaic-pack-GPL3-f089589.zip
	%CYGWIN_DIR%\bin\mv.exe LibRaw-LibRaw-* LibRaw-demosaic-pack-GPL3-f089589
)

IF NOT EXIST LibRaw-5c9b4fb (
	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/LibRaw-5c9b4fb.zip
	%CYGWIN_DIR%\bin\mv.exe LibRaw-LibRaw-* LibRaw-5c9b4fb

	
	pushd LibRaw-5c9b4fb
	
	rem echo.COPT_OPT="/openmp"> qtpfsgui_commands.in
	echo.CFLAGS_DP2=/I..\LibRaw-demosaic-pack-GPL2-6f851ba> qtpfsgui_commands.in
	echo.CFLAGSG2=/DLIBRAW_DEMOSAIC_PACK_GPL2>> qtpfsgui_commands.in
	echo.CFLAGS_DP3=/I..\LibRaw-demosaic-pack-GPL3-f089589>> qtpfsgui_commands.in
	echo.CFLAGSG3=/DLIBRAW_DEMOSAIC_PACK_GPL3>> qtpfsgui_commands.in
	echo.LCMS_DEF="/DUSE_LCMS2 /DCMS_DLL /I..\lcms2-493aac\include">> qtpfsgui_commands.in
	echo.LCMS_LIB="..\lcms2-493aac\bin\lcms2_dll.lib">> qtpfsgui_commands.in
REM	echo.JPEG_DEF="/DUSE_JPEG /I..\libjpeg">> qtpfsgui_commands.in
REM	echo.JPEG_LIB="..\libjpeg\libjpeg.lib">> qtpfsgui_commands.in
	
	nmake /f Makefile.msvc @qtpfsgui_commands.in clean
	nmake /f Makefile.msvc @qtpfsgui_commands.in bin\libraw.dll
	popd
)

IF NOT EXIST %TEMP_DIR%\gsl-1.15.tar (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/gsl-1.15.tar.gz ftp://ftp.gnu.org/gnu/gsl/gsl-1.15.tar.gz
	%CYGWIN_DIR%\bin\gzip -d %TEMP_DIR%/gsl-1.15.tar.gz
)
IF NOT EXIST %TEMP_DIR%\gsl-1.15-vc10.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/gsl-1.15-vc10.zip http://gladman.plushost.co.uk/oldsite/computing/gsl-1.15-vc10.zip
)
IF NOT EXIST gsl-1.15 (
	%CYGWIN_DIR%\bin\tar.exe -xf %TEMP_DIR%/gsl-1.15.tar
	%CYGWIN_DIR%\bin\unzip.exe -o -q -d gsl-1.15 %TEMP_DIR%/gsl-1.15-vc10.zip

	pushd gsl-1.15\build.vc10
	IF %VS_SHORT% EQU vc9 (
		%CYGWIN_DIR%\bin\sed.exe -i 's/Format Version 11.00/Format Version 10.00/g' gsl.lib.sln
	)
	devenv gsl.lib.sln /Upgrade
	devenv gsl.lib.sln /build "%Configuration%|%Platform%" /Project gslhdrs
	gslhdrs\%Platform%\%Configuration%\gslhdrs.exe
	devenv gsl.lib.sln /build "%Configuration%|%Platform%" /Project gsllib
	popd
)

IF NOT EXIST OpenExrStuff (
	pushd .
	mkdir OpenExrStuff
	cd OpenExrStuff
	
	for %%v in ("Deploy", "Deploy\include", "Deploy\lib\%Platform%\%Configuration%", "Deploy\bin\%Platform%\%Configuration%", "openexr-cvs") do (
		mkdir %%v
	)
	popd
	
	copy zlib-aa566e\*.h OpenExrStuff\Deploy\include
	copy zlib-aa566e\%Configuration%\*.lib OpenExrStuff\Deploy\lib\%Platform%\%Configuration%
	copy zlib-aa566e\%Configuration%\*.dll OpenExrStuff\Deploy\bin\%Platform%\%Configuration%
)
	
pushd OpenExrStuff\openexr-cvs
IF NOT EXIST IlmBase (
	%CYGWIN_DIR%\bin\cvs.exe -d :pserver:anonymous:anonymous@cvs.savannah.nongnu.org:/sources/openexr co IlmBase
	set openexr-compile=true
) ELSE (
	rem %CYGWIN_DIR%\bin\cvs.exe -d :pserver:anonymous:anonymous@cvs.savannah.nongnu.org:/sources/openexr update IlmBase
)
IF NOT EXIST OpenEXR (
	%CYGWIN_DIR%\bin\cvs.exe -d :pserver:anonymous:anonymous@cvs.savannah.nongnu.org:/sources/openexr co OpenEXR
	set openexr-compile=true
) ELSE (
	rem %CYGWIN_DIR%\bin\cvs.exe -d :pserver:anonymous:anonymous@cvs.savannah.nongnu.org:/sources/openexr update OpenEXR
)
popd

IF DEFINED openexr-compile (
	pushd OpenExrStuff\openexr-cvs\IlmBase\vc\vc9\IlmBase
	devenv IlmBase.sln /Upgrade
	devenv IlmBase.sln /build "%Configuration%|%Platform%"
	popd

	pushd OpenExrStuff\openexr-cvs\OpenEXR\vc\vc8\OpenEXR
	devenv OpenEXR.sln /Upgrade
	devenv OpenEXR.sln /build "%Configuration%|%Platform%" /Project IlmImf
	popd
)

IF %Platform% EQU Win32 (
	IF NOT EXIST %TEMP_DIR%\fftw-3.3.2-dll32.zip (
		%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/fftw-3.3.2-dll32.zip ftp://ftp.fftw.org/pub/fftw/fftw-3.3.2-dll32.zip
	)
) ELSE (
	IF NOT EXIST %TEMP_DIR%\fftw-3.3.2-dll64.zip (
		%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/fftw-3.3.2-dll64.zip ftp://ftp.fftw.org/pub/fftw/fftw-3.3.2-dll64.zip
		
	)
)

IF NOT EXIST fftw-3.3.2-dll (
	IF %Platform% EQU Win32 (
		%CYGWIN_DIR%\bin\unzip.exe -q -d fftw-3.3.2-dll %TEMP_DIR%/fftw-3.3.2-dll32.zip
	) ELSE (
		%CYGWIN_DIR%\bin\unzip.exe -q -d fftw-3.3.2-dll %TEMP_DIR%/fftw-3.3.2-dll64.zip
	)

	pushd fftw-3.3.2-dll
	lib /def:libfftw3-3.def
	lib /def:libfftw3f-3.def
	lib /def:libfftw3l-3.def
	popd
)

REM IF NOT EXIST %TEMP_DIR%\tbb40_20120613oss_win.zip (
REM 	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/tbb40_20120613oss_win.zip "http://threadingbuildingblocks.org/uploads/77/187/4.0 update 5/tbb40_20120613oss_win.zip"
REM )
REM 
REM IF NOT EXIST tbb40_20120613oss (
REM 	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/tbb40_20120613oss_win.zip
REM 	REM Everthing is already compiled, nothing to do!
REM )

REM GTest Patch for VS2012:
REM in internal_utils.cmake ~60
REM  if (MSVC_VERSION EQUAL 1700)
REM  	set(cxx_base_flags "${cxx_base_flags} -D_VARIADIC_MAX=10")
REM  endif ()
REM
REM IF NOT EXIST %TEMP_DIR%\gtest-1.6.0.zip (
REM 	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/gtest-1.6.0.zip http://googletest.googlecode.com/files/gtest-1.6.0.zip
REM )
REM 
REM IF NOT EXIST gtest-1.6.0 (
REM 	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/gtest-1.6.0.zip
REM 	
REM 	mkdir gtest-1.6.0.build
REM 	pushd gtest-1.6.0.build
REM 	%CMAKE_DIR%\bin\cmake.exe -G "%VS_CMAKE%" ..\gtest-1.6.0 -DBUILD_SHARED_LIBS=1
REM 	devenv gtest.sln /build "%Configuration%|%Platform%"
REM 	popd
REM )


IF NOT DEFINED L_BOOST_DIR (
	set L_BOOST_DIR=.
)

IF NOT EXIST %TEMP_DIR%\boost_1_50_0.zip (
	%CYGWIN_DIR%\bin\wget.exe -O %TEMP_DIR%/boost_1_50_0.zip http://sourceforge.net/projects/boost/files/boost/1.50.0/boost_1_50_0.zip/download
)

IF NOT EXIST %L_BOOST_DIR%\boost_1_50_0 (
	echo.Extracting boost. Be patient!

	pushd %L_BOOST_DIR%
	%CYGWIN_DIR%\bin\unzip.exe -q %TEMP_DIR%/boost_1_50_0.zip
	popd

	REM Currently only the header files are required of boost.
	REM Therefore the following code block is commented out.

REM 
REM 	pushd %L_BOOST_DIR%\boost_1_50_0
REM 	bootstrap.bat
REM 	popd
REM 	
REM 	pushd %L_BOOST_DIR%\boost_1_50_0
REM 	IF %Platform% EQU Win32 (
REM 		IF %Configuration% EQU Release (
REM 			b2.exe toolset=msvc variant=release
REM 		) ELSE (
REM 			b2.exe toolset=msvc variant=debug
REM 		)
REM 	) ELSE (
REM 		IF %Configuration% EQU Release (
REM 			b2.exe toolset=msvc variant=release address-model=64
REM 		) ELSE (
REM 			b2.exe toolset=msvc variant=debug address-model=64
REM 		)
REM 	)
	popd
)

REM Set Boost-directory as ENV variable (needed for CMake)
pushd %L_BOOST_DIR%\boost_1_50_0
SET BOOST_ROOT=%CD%
popd

IF NOT EXIST LuminanceHdrStuff (
	mkdir LuminanceHdrStuff
)
IF NOT EXIST LuminanceHdrStuff\qtpfsgui (
	pushd LuminanceHdrStuff
	%CYGWIN_DIR%\bin\git.exe clone git://git.code.sf.net/p/qtpfsgui/code qtpfsgui-code
	popd
) ELSE (
	pushd LuminanceHdrStuff\qtpfsgui
	IF %UPDATE_REPO_LUMINANCE% EQU 1 (
		%CYGWIN_DIR%\bin\git.exe pull
	)
	popd
)


IF NOT EXIST LuminanceHdrStuff\DEPs (
	pushd LuminanceHdrStuff
	mkdir DEPs
	cd DEPs
	mkdir include
	mkdir lib
	mkdir bin
	popd
	
	for %%v in ("libpng", "libjpeg", "lcms2", "exiv2", "libtiff", "libraw", "OpenEXR", "fftw3", "gsl") do (
		mkdir LuminanceHdrStuff\DEPs\include\%%v
		mkdir LuminanceHdrStuff\DEPs\lib\%%v
		mkdir LuminanceHdrStuff\DEPs\bin\%%v
	)
	
	mkdir LuminanceHdrStuff\DEPs\include\libraw\libraw

	copy OpenExrStuff\Deploy\include\*.h LuminanceHdrStuff\DEPs\include\OpenEXR
	copy OpenExrStuff\Deploy\lib\%Platform%\%Configuration%\*.lib LuminanceHdrStuff\DEPs\lib\OpenEXR
	copy OpenExrStuff\Deploy\bin\%Platform%\%Configuration%\*.dll LuminanceHdrStuff\DEPs\bin\OpenEXR

	copy fftw-3.3.2-dll\*.h LuminanceHdrStuff\DEPs\include\fftw3
	copy fftw-3.3.2-dll\*.lib LuminanceHdrStuff\DEPs\lib\fftw3
	copy fftw-3.3.2-dll\*.dll LuminanceHdrStuff\DEPs\bin\fftw3

	mkdir LuminanceHdrStuff\DEPs\include\gsl\gsl
	copy gsl-1.15\gsl\*.h LuminanceHdrStuff\DEPs\include\gsl\gsl
	copy gsl-1.15\build.vc10\lib\%Platform%\%Configuration%\*.lib LuminanceHdrStuff\DEPs\lib\gsl
	rem copy gsl-1.15\build.vc10\dll\*.dll LuminanceHdrStuff\DEPs\bin\gsl
)

robocopy tiff-4.0.3\libtiff LuminanceHdrStuff\DEPs\include\libtiff *.h /MIR >nul
robocopy tiff-4.0.3\libtiff LuminanceHdrStuff\DEPs\lib\libtiff *.lib /MIR /NJS >nul
robocopy tiff-4.0.3\libtiff LuminanceHdrStuff\DEPs\bin\libtiff *.dll /MIR /NJS >nul

rem robocopy expat: included indirectly in in exiv2
rem robocopy zlib: included indirectly in in exiv2
robocopy exiv2-2895\include LuminanceHdrStuff\DEPs\include\exiv2 *.h /MIR >nul
robocopy exiv2-2895\bin\%Platform%\Dynamic\%Configuration% LuminanceHdrStuff\DEPs\lib\exiv2 *.lib /MIR >nul
robocopy exiv2-2895\bin\%Platform%\Dynamic\%Configuration% LuminanceHdrStuff\DEPs\bin\exiv2 *.dll /MIR >nul

robocopy lpng1513 LuminanceHdrStuff\DEPs\include\libpng *.h /MIR >nul
robocopy lpng1513\%Configuration% LuminanceHdrStuff\DEPs\lib\libpng *.lib /MIR >nul
robocopy lpng1513\%Configuration% LuminanceHdrStuff\DEPs\bin\libpng *.dll /MIR >nul
	

robocopy LibRaw-5c9b4fb\libraw LuminanceHdrStuff\DEPs\include\libraw\libraw /MIR >nul
robocopy LibRaw-5c9b4fb\lib LuminanceHdrStuff\DEPs\lib\libraw *.lib /MIR >nul
robocopy LibRaw-5c9b4fb\bin LuminanceHdrStuff\DEPs\bin\libraw *.dll /MIR >nul
	
robocopy lcms2-493aac\include LuminanceHdrStuff\DEPs\include\lcms2 *.h /MIR >nul
robocopy lcms2-493aac\bin LuminanceHdrStuff\DEPs\lib\lcms2 *.lib /MIR /NJS >nul
robocopy lcms2-493aac\bin LuminanceHdrStuff\DEPs\bin\lcms2 *.dll /MIR /NJS >nul

robocopy libjpeg-turbo-867 LuminanceHdrStuff\DEPs\include\libjpeg *.h /MIR >nul
robocopy libjpeg-turbo-867.build LuminanceHdrStuff\DEPs\lib\libjpeg *.lib /MIR /NJS >nul
robocopy libjpeg-turbo-867.build LuminanceHdrStuff\DEPs\bin\libjpeg *.dll /MIR /NJS >nul

REM robocopy tbb40_20120613oss\include LuminanceHdrStuff\DEPs\include\tbb /MIR >nul
REM robocopy tbb40_20120613oss\lib\%CpuPlatform%\%VS_SHORT% LuminanceHdrStuff\DEPs\lib\tbb /MIR >nul
REM robocopy tbb40_20120613oss\bin\%CpuPlatform%\%VS_SHORT% LuminanceHdrStuff\DEPs\bin\tbb /MIR >nul


IF NOT EXIST LuminanceHdrStuff\qtpfsgui.build (
	mkdir LuminanceHdrStuff\qtpfsgui.build
)
pushd LuminanceHdrStuff\qtpfsgui.build


IF %OPTION_LUMINANCE_UPDATE_TRANSLATIONS% EQU 1 (
	set CMAKE_OPTIONS=-DUPDATE_TRANSLATIONS=1	
) ELSE (
	set CMAKE_OPTIONS=-UUPDATE_TRANSLATIONS
)
IF %OPTION_LUPDATE_NOOBSOLETE% EQU 1 (
	set CMAKE_OPTIONS=%CMAKE_OPTIONS% -DLUPDATE_NOOBSOLETE=1	
) ELSE (
	set CMAKE_OPTIONS=%CMAKE_OPTIONS% -ULUPDATE_NOOBSOLETE
)


set L_CMAKE_INCLUDE=..\DEPs\include\libtiff;..\DEPs\include\libpng;..\..\zlib-aa566e
set L_CMAKE_LIB=..\DEPs\lib\libtiff;..\DEPs\lib\libpng;..\..\zlib-aa566e\%Configuration%
set L_CMAKE_PROGRAM_PATH=%CYGWIN_DIR%\bin
set CMAKE_OPTIONS=%CMAKE_OPTIONS% -DPC_EXIV2_INCLUDEDIR=..\DEPs\include -DPC_EXIV2_LIBDIR=..\DEPs\lib\exiv2 -DCMAKE_INCLUDE_PATH=%L_CMAKE_INCLUDE% -DCMAKE_LIBRARY_PATH=%L_CMAKE_LIB% -DCMAKE_PROGRAM_PATH=%L_CMAKE_PROGRAM_PATH%

IF EXIST ..\..\gtest-1.6.0 (
	SET GTEST_ROOT=%CD%\..\..\gtest-1.6.0
)

%CMAKE_DIR%\bin\cmake.exe -G "%VS_CMAKE%" ..\qtpfsgui %CMAKE_OPTIONS%
popd

IF EXIST LuminanceHdrStuff\qtpfsgui.build\luminance-hdr.sln (
	pushd LuminanceHdrStuff\qtpfsgui.build	
	rem devenv luminance-hdr.sln /Upgrade
	devenv luminance-hdr.sln /build "%Configuration%|%Platform%"
	IF errorlevel 1	goto error_end
	popd
)

IF EXIST LuminanceHdrStuff\qtpfsgui.build\%Configuration%\luminance-hdr.exe (
	IF EXIST LuminanceHdrStuff\qtpfsgui.build\%Configuration% (
		
		IF NOT EXIST LuminanceHdrStuff\qtpfsgui.build\%Configuration%\LICENSE.txt (
			copy LuminanceHdrStuff\qtpfsgui\LICENSE LuminanceHdrStuff\qtpfsgui.build\%Configuration%\LICENSE.txt
		)
		IF NOT EXIST LuminanceHdrStuff\qtpfsgui.build\%Configuration%\align_image_stack.exe (
			copy %TEMP_DIR%\align_image_stack_%RawPlatform%.exe LuminanceHdrStuff\qtpfsgui.build\%Configuration%\align_image_stack.exe
			copy vcDlls\selected\* LuminanceHdrStuff\qtpfsgui.build\%Configuration%\
		)
		
		IF EXIST LuminanceHdrStuff\qtpfsgui.build\QtDlls\%Configuration%\ (
			IF NOT EXIST LuminanceHdrStuff\qtpfsgui.build\%Configuration%\zlib1.dll (
				mkdir LuminanceHdrStuff\qtpfsgui.build\%Configuration%\imageformats\
				mkdir LuminanceHdrStuff\qtpfsgui.build\%Configuration%\sqldrivers\
				copy LuminanceHdrStuff\qtpfsgui.build\QtDlls\%Configuration%\* LuminanceHdrStuff\qtpfsgui.build\%Configuration%\
				copy LuminanceHdrStuff\qtpfsgui.build\QtDlls\%Configuration%\imageformats\* LuminanceHdrStuff\qtpfsgui.build\%Configuration%\imageformats\
				copy LuminanceHdrStuff\qtpfsgui.build\QtDlls\%Configuration%\sqldrivers\* LuminanceHdrStuff\qtpfsgui.build\%Configuration%\sqldrivers\
			)
		)

		IF NOT EXIST LuminanceHdrStuff\qtpfsgui.build\%Configuration%\zlib1.dll (
			pushd LuminanceHdrStuff\DEPs\bin
			for %%v in ("lcms2\lcms2_DLL.dll", "exiv2\exiv2.dll", "exiv2\expat.dll", "OpenEXR\Half.dll", "OpenEXR\Iex.dll", "OpenEXR\IlmImf.dll", "OpenEXR\IlmThread.dll", "OpenEXR\zlib.dll", "libraw\libraw.dll", "fftw3\libfftw3f-3.dll", "libpng\libpng15.dll") do (
				copy %%v ..\..\qtpfsgui.build\%Configuration%
			)
			popd
			ren LuminanceHdrStuff\qtpfsgui.build\%Configuration%\lcms2_DLL.dll lcms2.dll
		)
		IF NOT EXIST LuminanceHdrStuff\qtpfsgui.build\%Configuration%\i18n\ (
			mkdir LuminanceHdrStuff\qtpfsgui.build\%Configuration%\i18n
		)
		IF NOT EXIST LuminanceHdrStuff\qtpfsgui.build\%Configuration%\help\ (
			mkdir LuminanceHdrStuff\qtpfsgui.build\%Configuration%\help
		)
		
		
		
		robocopy LuminanceHdrStuff\qtpfsgui.build\QtDlls\i18n LuminanceHdrStuff\qtpfsgui.build\%Configuration%\i18n *.qm >nul
		robocopy LuminanceHdrStuff\qtpfsgui.build LuminanceHdrStuff\qtpfsgui.build\%Configuration%\i18n *.qm >nul
		
		robocopy LuminanceHdrStuff\qtpfsgui\help LuminanceHdrStuff\qtpfsgui.build\%Configuration%\help /MIR >nul
	)
)



goto end

:error_end
pause

:end

endlocal