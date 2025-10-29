# Logger

A logger class, that can print out things in different colors for easy readability. Optionally it can also dump all the messages to a log file.

The `Logger.print` function prepends the filename and line from where it was called, so that you don't have to mentally keep track of where all your print statements are. 
Other functions print in different colors. but don't currently print out the file and line. 

The logger also includes the function `run_task()`, which can be used for quick benchmarks, and outputs the results with appropriate colors. (If `Logger.dump_logs` is `true`, 
then the besnchmark results will also be writen to the log file.)
