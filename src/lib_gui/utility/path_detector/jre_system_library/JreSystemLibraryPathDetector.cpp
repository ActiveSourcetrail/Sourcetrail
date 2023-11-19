#include "JreSystemLibraryPathDetector.h"

#include "JavaPathDetector.h"

#include "ApplicationSettings.h"
#include "FilePath.h"
#include "FileSystem.h"

JreSystemLibraryPathDetector::JreSystemLibraryPathDetector(
	std::shared_ptr<JavaPathDetector> javaPathDetector)
	: PathDetector(javaPathDetector->getName() + " System Library")
	, m_javaPathDetector(javaPathDetector)
{
}

std::vector<FilePath> JreSystemLibraryPathDetector::doGetPaths() const
{
	std::vector<FilePath> paths;
	for (const FilePath& jrePath: m_javaPathDetector->getPaths())
	{
		std::vector<FilePath> potentialPaths = {
			jrePath.getParentDirectory().getParentDirectory().getParentDirectory(),
			jrePath.getParentDirectory().getParentDirectory().getParentDirectory().getConcatenated(L"Contents").getConcatenated(L"Home")
		};
		for (const FilePath& javaRoot: potentialPaths )
		{
			for (const FilePath& jarPath:
				 FileSystem::getFilePathsFromDirectory(javaRoot.getConcatenated(L"lib"), {L".jar"}))
			{
				paths.push_back(jarPath);
			}
		}
		if (!paths.empty())
		{
			break;
		}
	}
	return paths;
}
