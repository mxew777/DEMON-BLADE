package com.mxew777.demonblade

import android.app.Activity
import android.os.Bundle
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.view.MotionEvent
import android.view.View
import kotlin.math.hypot

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        setContentView(ExploreView())
    }
}

private class ExploreView : View {
    private val p = Paint(Paint.ANTI_ALIAS_FLAG)
    private var px = 0f
    private var py = 0f
    private var targetX = 0f
    private var targetY = 0f
    private var moving = false
    private var score = 0
    private val motes = ArrayList<Pair<Float, Float>>()
    private val collected = BooleanArray(6)

    constructor() : super(null)
    constructor(context: android.content.Context) : super(context)

    override fun onDraw(c: Canvas) {
        super.onDraw(c)
        val w = width.toFloat()
        val h = height.toFloat()
        if (px == 0f && py == 0f) { px = w * .5f; py = h * .58f }
        c.drawColor(0xFF100E18.toInt())

        p.color = 0xFF211A2B.toInt()
        c.drawRect(0f, 0f, w, h, p)
        p.color = 0xFF30243A.toInt()
        for (x in 0..(w / 64).toInt()) c.drawLine(x * 64f, 0f, x * 64f, h, p)
        for (y in 0..(h / 64).toInt()) c.drawLine(0f, y * 64f, w, y * 64f, p)

        // Ancient ruins: scenery obstacles, not combat targets.
        p.color = 0xFF59465A.toInt()
        val ruins = listOf(RectF(w*.12f,h*.22f,w*.24f,h*.36f), RectF(w*.72f,h*.18f,w*.84f,h*.34f),
            RectF(w*.35f,h*.72f,w*.48f,h*.84f), RectF(w*.58f,h*.48f,w*.69f,h*.60f))
        ruins.forEach { c.drawRoundRect(it, 12f, 12f, p) }

        val spots = listOf(w*.18f to h*.62f, w*.36f to h*.28f, w*.55f to h*.18f,
            w*.82f to h*.58f, w*.68f to h*.82f, w*.42f to h*.52f)
        spots.forEachIndexed { i, pos ->
            if (!collected[i]) {
                p.color = 0xFFFFC45C.toInt()
                c.drawCircle(pos.first, pos.second, 10f, p)
                p.color = 0x66FFC45C
                c.drawCircle(pos.first, pos.second, 19f, p)
            }
        }

        if (moving) {
            val dx = targetX - px
            val dy = targetY - py
            val d = hypot(dx, dy)
            if (d > 5f) {
                px += dx / d * 4.2f
                py += dy / d * 4.2f
            } else moving = false
        }

        spots.forEachIndexed { i, pos ->
            if (!collected[i] && hypot(px-pos.first, py-pos.second) < 25f) {
                collected[i] = true
                score++
            }
        }

        p.color = 0xFFEA526F.toInt()
        c.drawCircle(px, py, 17f, p)
        p.color = 0xFFFFD5D9.toInt()
        c.drawCircle(px-5f, py-5f, 5f, p)

        p.color = 0xFFFFFFFF.toInt()
        p.textSize = 25f
        c.drawText("RUINS EXPLORATION", 28f, 38f, p)
        p.textSize = 19f
        c.drawText("Relics: $score / 6", 30f, 68f, p)
        p.color = 0xAAFFFFFF.toInt()
        c.drawText("Touch anywhere to move", 28f, h-24f, p)

        if (score == 6) {
            p.color = 0xFFFFD27A.toInt()
            p.textSize = 30f
            c.drawText("ALL RELICS FOUND", w*.5f-115f, h*.5f, p)
        }
        postInvalidateDelayed(16)
    }

    override fun onTouchEvent(e: MotionEvent): Boolean {
        when (e.action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE -> {
                targetX = e.x
                targetY = e.y
                moving = true
                invalidate()
                return true
            }
            MotionEvent.ACTION_UP -> { moving = false; return true }
        }
        return true
    }
}
