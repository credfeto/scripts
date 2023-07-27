#! /bin/sh
rm ~/.nuget/NuGet/NuGet.Config
ln -s $(pwd)/nuget.config ~/.nuget/NuGet/NuGet.Config
