$path = 'lib/features/tasks/presentation/screens/tasks_screen.dart'  
$c = [IO.File]::ReadAllText($path)  
$old = 'ReplaceThisWithTheOriginalCard'  
$new = 'ReplaceThisWithNewCard'  
$c = $c.Replace($old, $new)  
[IO.File]::WriteAllText($path, $c) 
