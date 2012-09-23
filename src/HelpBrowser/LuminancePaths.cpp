//
// C++ Implementation: fmpaths
//
// Description: 
//
//
// Author: Pierre Marchand <pierremarc@oep-h.com>, (C) 2008
//
// Copyright: See COPYING file that comes with this distribution
//
// Adapted to Luminance HDR
//

#include "LuminancePaths.h"
#include "help-path.hxx"

#include <QApplication>

LuminancePaths *LuminancePaths::instance = 0;
LuminancePaths * LuminancePaths::getThis()
{
	if(!instance)
		instance = new LuminancePaths;
	return instance;
}

QString LuminancePaths::HelpDir()
{
	if(getThis()->LuminancePathsDB.contains("HelpDir"))
		return getThis()->LuminancePathsDB["HelpDir"];
	QString hf;
	QString dirsep(QDir::separator());

    hf = LocalizedDirPath(QApplication::applicationDirPath() + dirsep + "help" + dirsep);
    QDir dirHelp(hf);
    if (!dirHelp.exists())
    {
#ifdef Q_WS_MAC
        hf = LocalizedDirPath(QApplication::applicationDirPath() + dirsep + "../Resources/help/en" + dirsep);
#elif _WIN32
        // no fall-back
#elif __FreeBSD__
        hf = LocalizedDirPath("/usr/local/share/doc/luminance-hdr/");
#else
        //	hf = LocalizedDirPath( PREFIX + dirsep + "share" + dirsep + "fontmatrix" + dirsep + "help" + dirsep );
        //hf = LocalizedDirPath("usr" + dirsep + "share" + dirsep + "luminance-hdr" + dirsep + "help" + dirsep);
        hf = LocalizedDirPath(HELPDIR + dirsep);
#endif
    }

	getThis()->LuminancePathsDB["HelpDir"] = hf;

	return getThis()->LuminancePathsDB["HelpDir"];
}

QString LuminancePaths::LocalizedDirPath(const QString & base, const QString& fallback )
{	
	QString sep("_");
	QStringList l_c(QLocale::system().name().split(sep));
	QString langcode( l_c.first() );
	QString countrycode(l_c.last());

	QStringList names;
	if((!langcode.isEmpty()) || (!countrycode.isEmpty()))
	{
		names << base + langcode + sep + countrycode ;
		names << base + langcode  ;
	}
	names << base + fallback  ;
	names << base  ;
	
	foreach(QString t, names)
	{
		QDir d(t);
		if( d.exists() )
			return d.absolutePath() + QString(QDir::separator()) ;
	}
	
	return QString();
}
