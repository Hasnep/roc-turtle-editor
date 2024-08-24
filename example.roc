module [main]

import turtle.Turtle

initialLength = 100
initialAngle = Num.pi / 6

main = \{} ->
    Turtle.new {}
    |> Turtle.setPen Up
    |> Turtle.moveTo { x: 0, y: 250 }
    |> Turtle.turnTo (-Num.pi / 2)
    |> Turtle.setPen Down
    |> drawBranch initialLength initialAngle

drawBranch = \t, length, angle ->
    if length < 3 then
        t
    else
        t2 = t |> Turtle.setPen Down |> Turtle.forward length |> Turtle.setPen Up
        p = Turtle.getPosition t2
        d = Turtle.getDirection t2
        t3 =
            t2
            |> Turtle.turn angle
            |> drawBranch (length * 0.75) angle
            |> Turtle.moveTo p
            |> Turtle.turnTo d
        t4 =
            t3
            |> Turtle.turn -angle
            |> drawBranch (length * 0.75) angle
            |> Turtle.moveTo p
            |> Turtle.turnTo d
        t4
